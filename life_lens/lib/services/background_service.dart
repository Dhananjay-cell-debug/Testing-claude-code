import 'dart:async';
import 'dart:ui';
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

  // Update notification every minute
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

  service.on('stop').listen((event) {
    service.stopSelf();
  });
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
}
