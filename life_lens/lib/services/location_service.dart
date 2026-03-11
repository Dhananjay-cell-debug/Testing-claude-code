import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../models/life_event.dart';

class LifeLocationService {
  final _db = DatabaseHelper();
  Position? _lastPosition;

  Future<void> initialize() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
  }

  Future<void> collectAndSave() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );

      // Only save if moved significantly (>50 meters)
      if (_lastPosition != null) {
        final distance = Geolocator.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          position.latitude,
          position.longitude,
        );
        if (distance < 50) {
          _lastPosition = position;
          return;
        }
      }

      _lastPosition = position;

      String? address;
      String? placeName;

      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          address = [p.street, p.locality, p.country]
              .where((s) => s != null && s.isNotEmpty)
              .join(', ');
          placeName = _inferPlaceName(p);
        }
      } catch (_) {
        // Geocoding failed, save coords only
      }

      await _db.insertLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
        placeName: placeName,
      );

      await _db.insertEvent(LifeEvent(
        type: 'location',
        timestamp: DateTime.now(),
        data: {
          'latitude': position.latitude.toString(),
          'longitude': position.longitude.toString(),
          'address': address ?? '',
          'place_name': placeName ?? '',
          'accuracy': position.accuracy.toString(),
        },
      ));

      // Update shared prefs for quick access
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_location', placeName ?? address ?? 'Unknown');
      await prefs.setDouble('last_lat', position.latitude);
      await prefs.setDouble('last_lng', position.longitude);
    } catch (e) {
      // Location unavailable, skip
    }
  }

  String _inferPlaceName(Placemark p) {
    // Try to give meaningful name based on geocoding data
    if (p.name != null && p.name!.isNotEmpty && p.name != p.street) {
      return p.name!;
    }
    if (p.subLocality != null && p.subLocality!.isNotEmpty) {
      return p.subLocality!;
    }
    if (p.locality != null && p.locality!.isNotEmpty) {
      return p.locality!;
    }
    return 'Unknown location';
  }

  Future<String> getLocationSummaryForDay(DateTime day) async {
    final locations = await _db.getLocationsForDay(day);
    if (locations.isEmpty) return 'No location data recorded.';

    final places = <String>{};
    for (final loc in locations) {
      final name = loc['place_name'] as String?;
      final address = loc['address'] as String?;
      if (name != null && name.isNotEmpty) places.add(name);
      else if (address != null && address.isNotEmpty) places.add(address);
    }

    if (places.isEmpty) return 'Stayed in one location today.';
    return 'Visited: ${places.join(', ')}';
  }
}
