import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../models/life_event.dart';

/// Tracks screen on/off events by polling app usage patterns
/// (Full BroadcastReceiver requires native code; this is the Flutter layer)
class ScreenService {
  final _db = DatabaseHelper();
  bool _isScreenOn = true;
  DateTime? _screenOnTime;
  int _pickupCount = 0;

  void onScreenOn() async {
    if (!_isScreenOn) {
      _isScreenOn = true;
      _screenOnTime = DateTime.now();
      _pickupCount++;

      await _db.insertEvent(LifeEvent(
        type: 'screen',
        timestamp: DateTime.now(),
        data: {'state': 'on', 'pickup_number': _pickupCount.toString()},
      ));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('today_pickups', _pickupCount);
    }
  }

  void onScreenOff() async {
    if (_isScreenOn) {
      _isScreenOn = false;
      final sessionDuration = _screenOnTime != null
          ? DateTime.now().difference(_screenOnTime!).inSeconds
          : 0;

      await _db.insertEvent(LifeEvent(
        type: 'screen',
        timestamp: DateTime.now(),
        durationSeconds: sessionDuration,
        data: {
          'state': 'off',
          'session_seconds': sessionDuration.toString(),
        },
      ));
    }
  }

  int get pickupCount => _pickupCount;
  bool get isScreenOn => _isScreenOn;
}
