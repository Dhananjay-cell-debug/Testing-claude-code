import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../models/trusted_contact.dart';
import '../models/safety_incident.dart';
import 'emergency_responder.dart';

enum SafetyEventType { activated, escalated, checkinRequired, resolved, stealthMode }

class SafetyEvent {
  final SafetyEventType type;
  final ThreatLevel? level;
  final int? incidentId;
  SafetyEvent(this.type, {this.level, this.incidentId});
}

/// Central safety orchestrator — singleton.
/// The UI and background service both use this.
///
/// Flow:
///   activate(level) → starts recording + SMS + timer
///   timer fires → emits checkinRequired → UI shows popup
///   escalate(newLevel) → upgrades actions
///   triggerImmediate() → 112 call + stealth mode
///   resolve() → stops everything, saves incident
class SafetyService {
  static final SafetyService _instance = SafetyService._internal();
  factory SafetyService() => _instance;
  SafetyService._internal();

  final _db = DatabaseHelper();
  final _responder = EmergencyResponder();
  final _eventController = StreamController<SafetyEvent>.broadcast();

  Stream<SafetyEvent> get events => _eventController.stream;

  // SharedPreferences keys — used by background service to fire checkin
  // notifications even when the app is killed or the screen is locked.
  static const _kActive = 'safety_is_active';
  static const _kLevel = 'safety_level';
  static const _kNextCheckin = 'safety_next_checkin_at';

  bool _isActive = false;
  ThreatLevel _currentLevel = ThreatLevel.none;
  int? _currentIncidentId;
  String? _currentRecordingPath;
  Timer? _checkinTimer;
  Timer? _locationPingTimer;

  bool get isActive => _isActive;
  ThreatLevel get currentLevel => _currentLevel;
  int? get currentIncidentId => _currentIncidentId;

  // ── Activate Safety Mode ───────────────────────────────────────────────────

  Future<void> activate(ThreatLevel level) async {
    if (level == ThreatLevel.none) return;

    _isActive = true;
    _currentLevel = level;

    // Get current location
    final position = await _responder.getCurrentLocation();
    final now = DateTime.now();

    // Save incident to DB
    _currentIncidentId = await _db.startSafetyIncident(
      threatLevel: level,
      lat: position?.latitude,
      lng: position?.longitude,
      address: null,
    );

    // Get user name + trusted contacts
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name') ?? 'Someone';
    final contacts = await _db.getTrustedContacts();

    if (level == ThreatLevel.immediate) {
      await triggerImmediate(name: name, contacts: contacts, position: position, now: now);
      return;
    }

    // Path A / B: start recording + send alerts + start 5-min timer
    _currentRecordingPath = await _responder.startRecording();
    if (_currentIncidentId != null && _currentRecordingPath != null) {
      await _db.updateIncidentRecording(_currentIncidentId!, _currentRecordingPath!);
    }

    // Send alert SMS to trusted contacts
    if (contacts.isNotEmpty) {
      final msg = _responder.buildAlertMessage(
        name: name,
        level: level,
        position: position,
        time: now,
      );
      await _responder.sendSmsBlast(contacts: contacts, message: msg);
    }

    // Start live location ping every 30 seconds
    _startLocationPing();

    // Start 5-minute checkin timer (in-app + background)
    _startCheckinTimer();
    await _persistState(level);

    _eventController.add(SafetyEvent(SafetyEventType.activated, level: level));
  }

  // ── Escalate ───────────────────────────────────────────────────────────────

  Future<void> escalate(ThreatLevel newLevel) async {
    if (!_isActive) return;
    if (newLevel.index <= _currentLevel.index) return;

    _currentLevel = newLevel;
    if (_currentIncidentId != null) {
      await _db.updateIncidentThreat(_currentIncidentId!, newLevel);
    }

    if (newLevel == ThreatLevel.immediate) {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('user_name') ?? 'Someone';
      final contacts = await _db.getTrustedContacts();
      final position = await _responder.getCurrentLocation();
      await triggerImmediate(name: name, contacts: contacts, position: position, now: DateTime.now());
      return;
    }

    // Update persisted level so background service checkin uses correct label
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLevel, newLevel.key);

    // Re-send SMS with escalated level
    final name = prefs.getString('user_name') ?? 'Someone';
    final contacts = await _db.getTrustedContacts();
    final position = await _responder.getCurrentLocation();
    if (contacts.isNotEmpty) {
      final msg = _responder.buildAlertMessage(name: name, level: newLevel, position: position, time: DateTime.now());
      await _responder.sendSmsBlast(contacts: contacts, message: msg);
    }

    // Restart 5-min timer
    _startCheckinTimer();

    _eventController.add(SafetyEvent(SafetyEventType.escalated, level: newLevel));
  }

  // ── Immediate Danger (Path C) ──────────────────────────────────────────────

  Future<void> triggerImmediate({
    String? name,
    List<TrustedContact>? contacts,
    Position? position,
    DateTime? now,
  }) async {
    _isActive = true;
    _currentLevel = ThreatLevel.immediate;

    now ??= DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    name ??= prefs.getString('user_name') ?? 'Someone';
    contacts ??= await _db.getTrustedContacts();
    position ??= await _responder.getCurrentLocation();

    // Save/update incident
    _currentIncidentId ??= await _db.startSafetyIncident(
      threatLevel: ThreatLevel.immediate,
      lat: position?.latitude,
      lng: position?.longitude,
      address: null,
    );
    if (_currentIncidentId != null) {
      await _db.updateIncidentThreat(_currentIncidentId!, ThreatLevel.immediate);
    }

    // Step 1: Start recording sequentially so DB update is guaranteed before proceeding
    final path = await _responder.startRecording();
    _currentRecordingPath = path;
    if (_currentIncidentId != null && path != null) {
      await _db.updateIncidentRecording(_currentIncidentId!, path);
    }

    // Step 2: Fire call + SMS in parallel (both are fire-and-forget actions)
    final smsMsg = _responder.buildAlertMessage(
      name: name,
      level: ThreatLevel.immediate,
      position: position,
      time: now,
    );
    await Future.wait([
      _responder.callEmergency(number: '112'),
      if (contacts.isNotEmpty) _responder.sendSmsBlast(contacts: contacts, message: smsMsg),
    ]);

    // Continue location pinging every 15 seconds in immediate mode
    _locationPingTimer?.cancel();
    _locationPingTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      final pos = await _responder.getCurrentLocation();
      if (_currentIncidentId != null && pos != null) {
        await _db.addLocationToTrail(_currentIncidentId!, pos.latitude, pos.longitude);
      }
      // Resend location SMS every minute
    });

    _eventController.add(SafetyEvent(SafetyEventType.stealthMode, level: ThreatLevel.immediate));
  }

  // ── Resolve ────────────────────────────────────────────────────────────────

  Future<void> resolve() async {
    _checkinTimer?.cancel();
    _locationPingTimer?.cancel();

    await _responder.stopRecording();

    if (_currentIncidentId != null) {
      await _db.resolveIncident(_currentIncidentId!);
    }

    // Notify contacts that user is safe
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name') ?? 'Someone';
    final contacts = await _db.getTrustedContacts();
    if (contacts.isNotEmpty) {
      await _responder.sendSmsBlast(
        contacts: contacts,
        message: _responder.buildAlertMessage(
          name: name,
          level: ThreatLevel.none,
          position: null,
          time: DateTime.now(),
        ),
      );
    }

    _isActive = false;
    _currentLevel = ThreatLevel.none;
    _currentIncidentId = null;
    _currentRecordingPath = null;

    // Clear persisted state so background service stops firing checkin notifications
    // (reuse the same prefs instance already fetched above)
    await prefs.setBool(_kActive, false);
    await prefs.remove(_kLevel);
    await prefs.remove(_kNextCheckin);
    await prefs.remove('safety_checkin_pending');

    _eventController.add(SafetyEvent(SafetyEventType.resolved));
  }

  // ── Timers ─────────────────────────────────────────────────────────────────

  void _startCheckinTimer() {
    _checkinTimer?.cancel();
    _checkinTimer = Timer(const Duration(minutes: 5), () {
      if (_isActive) {
        _eventController.add(SafetyEvent(SafetyEventType.checkinRequired, level: _currentLevel));
      }
    });
  }

  /// Called by check-in popup when user selects "Still uncomfortable" —
  /// restarts the 5-minute timer so the next check-in fires on schedule.
  /// Also updates SharedPrefs so the background service fires correctly
  /// even if the app is later killed or the screen locks.
  void restartCheckinTimer() {
    _startCheckinTimer();
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt(
        _kNextCheckin,
        DateTime.now().add(const Duration(minutes: 5)).millisecondsSinceEpoch,
      );
    });
  }

  // ── SharedPrefs persistence (inter-isolate bridge) ─────────────────────────

  Future<void> _persistState(ThreatLevel level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kActive, true);
    await prefs.setString(_kLevel, level.key);
    await prefs.setInt(
      _kNextCheckin,
      DateTime.now().add(const Duration(minutes: 5)).millisecondsSinceEpoch,
    );
  }

  void _startLocationPing() {
    _locationPingTimer?.cancel();
    _locationPingTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      final pos = await _responder.getCurrentLocation();
      if (_currentIncidentId != null && pos != null) {
        await _db.addLocationToTrail(_currentIncidentId!, pos.latitude, pos.longitude);
      }
    });
  }

  void dispose() {
    _checkinTimer?.cancel();
    _locationPingTimer?.cancel();
    _eventController.close();
    _responder.dispose();
  }
}
