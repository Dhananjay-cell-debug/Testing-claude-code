import 'package:app_usage/app_usage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';

// Packages to filter out (system apps)
const _systemPackages = {
  'com.android.systemui',
  'com.android.launcher',
  'com.android.launcher3',
  'com.google.android.apps.nexuslauncher',
  'com.android.phone',
  'com.android.settings',
  'com.android.inputmethod',
};

// Human-readable app names
const _appNames = {
  'com.instagram.android': 'Instagram',
  'com.google.android.youtube': 'YouTube',
  'com.twitter.android': 'Twitter/X',
  'com.facebook.katana': 'Facebook',
  'com.snapchat.android': 'Snapchat',
  'com.zhiliaoapp.musically': 'TikTok',
  'com.whatsapp': 'WhatsApp',
  'com.google.android.gm': 'Gmail',
  'com.google.android.apps.docs': 'Google Docs',
  'com.google.android.apps.sheets': 'Google Sheets',
  'com.slack': 'Slack',
  'com.notion.id': 'Notion',
  'com.spotify.music': 'Spotify',
  'com.netflix.mediaclient': 'Netflix',
  'com.amazon.mShop.android.shopping': 'Amazon',
  'com.google.android.apps.maps': 'Google Maps',
  'com.google.android.chrome': 'Chrome',
  'org.telegram.messenger': 'Telegram',
  'com.discord': 'Discord',
  'com.linkedin.android': 'LinkedIn',
  'com.reddit.frontpage': 'Reddit',
};

class UsageStatsService {
  final _db = DatabaseHelper();

  /// Collect app usage and save to DB.
  /// Queries CUMULATIVE usage from midnight to now, so each call overwrites
  /// the previous value — no duplicate rows, no inflated totals.
  Future<void> collectAndSave() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final dateKey = _db.dateKey(now);

      // Full-day cumulative usage (midnight → now)
      final dayInfos = await AppUsage().getAppUsage(startOfDay, now);

      // Last-5-min window to detect phone activity (for pickup counting)
      final fiveMinAgo = now.subtract(const Duration(minutes: 5));
      final recentInfos = await AppUsage().getAppUsage(fiveMinAgo, now);
      final activeNow = recentInfos
          .where((i) => !_systemPackages.contains(i.packageName) && i.usage.inSeconds >= 5)
          .isNotEmpty;

      for (final info in dayInfos) {
        if (_systemPackages.contains(info.packageName)) continue;
        if (info.usage.inSeconds < 5) continue;

        final appName = _appNames[info.packageName] ?? _friendlyName(info.packageName);

        // Upsert: overwrites today's row with latest cumulative total
        await _db.upsertAppSession(
          packageName: info.packageName,
          appName: appName,
          dateKey: dateKey,
          durationSeconds: info.usage.inSeconds,
        );
      }

      // Increment pickup count if phone was actively used in this 5-min window
      if (activeNow) {
        final currentPickups = await _db.getDailyPickups(dateKey);
        await _db.saveDailyPickups(dateKey, currentPickups + 1);
      }

      // Update shared prefs for notification bar
      final screenMins = await _db.getTotalScreenTimeForDay(now);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('today_screen_minutes', screenMins);
    } catch (e) {
      // UsageStats permission not granted yet - will retry next cycle
    }
  }

  /// Get today's app usage summary as human-readable text for Claude
  Future<String> getDailyUsageSummary(DateTime day) async {
    final usage = await _db.getAppUsageForDay(day);
    if (usage.isEmpty) return 'No app usage data recorded.';

    final buffer = StringBuffer('App usage today:\n');
    int rank = 1;
    for (final entry in usage.entries.take(10)) {
      final hours = entry.value ~/ 60;
      final mins = entry.value % 60;
      final timeStr = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';
      buffer.writeln('${rank++}. ${entry.key}: $timeStr');
    }
    return buffer.toString();
  }

  String _friendlyName(String packageName) {
    final parts = packageName.split('.');
    if (parts.length >= 2) {
      return parts.last
          .split('_')
          .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');
    }
    return packageName;
  }

  String _categorize(String packageName) {
    final pkg = packageName.toLowerCase();
    if (['instagram', 'youtube', 'tiktok', 'facebook', 'twitter', 'snapchat', 'reddit']
        .any(pkg.contains)) return 'social';
    if (['gmail', 'slack', 'notion', 'docs', 'sheets', 'outlook', 'teams']
        .any(pkg.contains)) return 'productivity';
    if (['spotify', 'netflix', 'prime', 'disney', 'hulu']
        .any(pkg.contains)) return 'entertainment';
    if (['maps', 'uber', 'lyft', 'ola']
        .any(pkg.contains)) return 'navigation';
    if (['whatsapp', 'telegram', 'discord', 'signal']
        .any(pkg.contains)) return 'messaging';
    return 'other';
  }
}
