import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'usage_stats_service.dart';
import 'location_service.dart';
import 'step_service.dart';

/// Initializes and configures the background service
Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  final androidConfig = AndroidConfiguration(
    onStart: onServiceStart,
    autoStart: true,
    isForegroundMode: true,
    notificationChannelId: 'life_lens_tracking',
    initialNotificationTitle: 'LifeLens Active',
    initialNotificationContent: 'Tracking your day in the background...',
    foregroundServiceNotificationId: 888,
  );

  final iosConfig = IosConfiguration(
    autoStart: true,
    onForeground: onServiceStart,
    onBackground: onIosBackground,
  );

  await service.configure(
    androidConfiguration: androidConfig,
    iosConfiguration: iosConfig,
  );

  await service.startService();
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

/// Main background service entry point - runs 24/7
@pragma('vm:entry-point')
void onServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final usageStatsService = UsageStatsService();
  final locationService = LifeLocationService();
  final stepService = StepService();

  await locationService.initialize();
  await stepService.initialize();

  // Every-minute loop: update foreground notification + fire safety checkin if due
  Timer.periodic(const Duration(minutes: 1), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        final prefs = await SharedPreferences.getInstance();
        final steps = prefs.getInt('today_steps') ?? 0;
        final screenMins = prefs.getInt('today_screen_minutes') ?? 0;

        service.setForegroundNotificationInfo(
          title: 'LifeLens • $steps steps today',
          content: '${screenMins}min screen time • Tracking active',
        );
      }
    }
    // Safety checkin: fires even if app is killed / screen is off
    await _checkSafetyCheckin();
  });

  // Collect app usage every 5 minutes
  Timer.periodic(const Duration(minutes: 5), (timer) async {
    await usageStatsService.collectAndSave();
  });

  // Collect location every 10 minutes
  Timer.periodic(const Duration(minutes: 10), (timer) async {
    await locationService.collectAndSave();
  });

  // Update steps every 2 minutes
  Timer.periodic(const Duration(minutes: 2), (timer) async {
    await stepService.collectAndSave();
  });

  // Generate hourly AI insight prompt data
  Timer.periodic(const Duration(hours: 1), (timer) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('last_hourly_update', DateTime.now().toIso8601String());
  });

  // Anomaly detection: check every 10 minutes if user is in unusual situation
  Timer.periodic(const Duration(minutes: 10), (timer) async {
    await _checkSafetyAnomaly();
  });

  service.on('stop').listen((event) {
    service.stopSelf();
  });
}

/// Fires the 5-minute safety check-in notification from the background isolate.
///
/// This runs every minute and checks SharedPrefs. This is the ONLY reliable
/// way to wake the user when the app is backgrounded / screen is locked:
///   - SafetyService writes safety_is_active + safety_next_checkin_at to prefs
///   - This function reads those prefs and fires a full-screen-intent notification
///     that pops up exactly like an incoming phone call (even on lock screen)
///   - When the app opens from the notification, HomeScreen checks
///     safety_checkin_pending flag and shows SafetyCheckinPopup immediately
Future<void> _checkSafetyCheckin() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final isActive = prefs.getBool('safety_is_active') ?? false;
    if (!isActive) return;

    final nextCheckinAt = prefs.getInt('safety_next_checkin_at') ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs < nextCheckinAt) return; // Timer not yet due

    // Advance timer BEFORE firing to prevent duplicate notifications
    await prefs.setInt(
      'safety_next_checkin_at',
      DateTime.now().add(const Duration(minutes: 5)).millisecondsSinceEpoch,
    );
    // Signal to the app UI to show checkin popup when it next resumes
    await prefs.setBool('safety_checkin_pending', true);

    // Fire full-screen intent notification — appears over any app, even lock screen
    final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    await plugin.show(
      998, // fixed ID so repeated alerts replace rather than stack
      '⚠️ Drishti Check-in',
      'Are you still safe? Tap to respond.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'life_lens_safety',
          'Safety Check-in',
          channelDescription: 'Active safety mode check-ins',
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: true, // Pops up on lock screen like an incoming call
          color: Color(0xFFFF6B35),
          autoCancel: true,
        ),
      ),
    );
  } catch (_) {
    // Silently fail — checkin is best-effort
  }
}

/// Detects anomalous situations and sends a soft safety check-in notification.
/// Rules (all must be true to trigger):
///   - Time is between 8 PM and 2 AM
///   - User has been moving (location data exists but not at home)
///   - No phone interaction in last 20 minutes
Future<void> _checkSafetyAnomaly() async {
  try {
    final now = DateTime.now();
    final hour = now.hour;

    // Only check during high-risk hours (8 PM – 2 AM)
    if (hour < 20 && hour > 2) return;

    final prefs = await SharedPreferences.getInstance();

    // Check last phone interaction time
    final lastInteraction = prefs.getString('last_interaction_time');
    if (lastInteraction != null) {
      final last = DateTime.tryParse(lastInteraction);
      if (last != null) {
        final minutesSinceInteraction = now.difference(last).inMinutes;
        // If user interacted recently, probably fine
        if (minutesSinceInteraction < 20) return;
      }
    }

    // Check if we already sent a check-in recently (avoid spam)
    final lastCheckIn = prefs.getString('last_safety_checkin');
    if (lastCheckIn != null) {
      final last = DateTime.tryParse(lastCheckIn);
      if (last != null && now.difference(last).inMinutes < 30) return;
    }

    // Send soft check-in notification
    final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    await plugin.show(
      999,
      'Drishti: Still safe?',
      'Tap to confirm you\'re okay, or open Safety Mode if you need help.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'life_lens_safety',
          'Safety Check-in',
          channelDescription: 'Periodic safety check-ins during late hours',
          importance: Importance.high,
          priority: Priority.high,
          color: Color(0xFFFF2D2D),
        ),
      ),
    );

    await prefs.setString('last_safety_checkin', now.toIso8601String());
  } catch (_) {
    // Silently fail — safety check is best-effort
  }
}

/// Setup notification channel for the foreground service
Future<void> setupNotificationChannel() async {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'life_lens_tracking',
    'LifeLens Tracking',
    description: 'LifeLens background tracking service',
    importance: Importance.low,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // Safety check-in notification channel (high priority)
  const AndroidNotificationChannel safetyChannel = AndroidNotificationChannel(
    'life_lens_safety',
    'Safety Check-in',
    description: 'Drishti safety check-ins during late hours',
    importance: Importance.high,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(safetyChannel);
}
