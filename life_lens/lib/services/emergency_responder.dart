import 'dart:io';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../models/trusted_contact.dart';
import '../models/safety_incident.dart';

/// Handles the actual emergency actions:
/// - Audio recording (silently, screen off safe)
/// - SMS blast to trusted contacts
/// - Emergency call to 112 or 1091
/// - Live location fetching
class EmergencyResponder {
  static const _channel = MethodChannel('com.dhananjay.lifelens/native');

  final AudioRecorder _recorder = AudioRecorder();
  String? _currentRecordingPath;

  // ── Recording ──────────────────────────────────────────────────────────────

  Future<String?> startRecording() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) return null;

      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final path = '${dir.path}/safety_$ts.m4a';

      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 44100, bitRate: 128000),
        path: path,
      );
      _currentRecordingPath = path;
      return path;
    } catch (_) {
      return null;
    }
  }

  Future<String?> stopRecording() async {
    try {
      final path = await _recorder.stop();
      _currentRecordingPath = null;
      return path;
    } catch (_) {
      return _currentRecordingPath;
    }
  }

  Future<bool> isRecording() async {
    try {
      return await _recorder.isRecording();
    } catch (_) {
      return false;
    }
  }

  // ── Calls ──────────────────────────────────────────────────────────────────

  /// Directly calls emergency number (no dialer UI shown).
  /// Requires CALL_PHONE permission.
  Future<void> callEmergency({String number = '112'}) async {
    try {
      await _channel.invokeMethod('makeEmergencyCall', {'number': number});
    } catch (_) {}
  }

  /// Calls women's helpline 1091
  Future<void> callWomensHelpline() async => callEmergency(number: '1091');

  // ── SMS ────────────────────────────────────────────────────────────────────

  /// Sends SMS to all trusted contacts simultaneously.
  /// Uses native SmsManager — works without internet.
  Future<void> sendSmsBlast({
    required List<TrustedContact> contacts,
    required String message,
  }) async {
    for (final contact in contacts) {
      try {
        await _channel.invokeMethod('sendSms', {
          'phone': contact.phone,
          'message': message,
        });
      } catch (_) {
        // continue to next contact even if one fails
      }
    }
  }

  // ── Location ────────────────────────────────────────────────────────────────

  Future<Position?> getCurrentLocation() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );
    } catch (_) {
      return null;
    }
  }

  // ── Message Templates ──────────────────────────────────────────────────────

  String buildAlertMessage({
    required String name,
    required ThreatLevel level,
    required Position? position,
    required DateTime time,
  }) {
    final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    final locationStr = position != null
        ? 'https://maps.google.com/?q=${position.latitude},${position.longitude}'
        : 'Location unavailable';

    switch (level) {
      case ThreatLevel.uncomfortable:
        return '⚠️ LifeLens Alert: $name is feeling unsafe while walking alone at $timeStr.\nLive location: $locationStr\nPlease check in with her.';
      case ThreatLevel.following:
        return '🚨 URGENT: $name thinks she is being followed at $timeStr.\nLocation: $locationStr\nCall her immediately.';
      case ThreatLevel.immediate:
        return '🆘 EMERGENCY: $name is in IMMEDIATE DANGER at $timeStr.\nLocation: $locationStr\nCall 112 NOW. Go to her location.';
      default:
        return '✅ $name is now safe. Thank you for your support.';
    }
  }

  String build112Message({
    required String name,
    required Position? position,
    required DateTime time,
  }) {
    final locationStr = position != null
        ? 'GPS: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}'
        : 'GPS unavailable';
    return 'EMERGENCY via LifeLens: $name needs immediate help. $locationStr. Time: ${time.toIso8601String()}';
  }

  void dispose() {
    _recorder.dispose();
  }
}
