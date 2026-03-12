/// Represents a single tracked event in the user's life
class LifeEvent {
  final int? id;
  final String type; // app_usage, location, activity, screen, step, wifi, bluetooth
  final DateTime timestamp;
  final int durationSeconds;
  final Map<String, dynamic> data;

  LifeEvent({
    this.id,
    required this.type,
    required this.timestamp,
    this.durationSeconds = 0,
    required this.data,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'duration_seconds': durationSeconds,
        'data': _encodeData(data),
      };

  static LifeEvent fromMap(Map<String, dynamic> map) => LifeEvent(
        id: map['id'] as int?,
        type: map['type'] as String,
        timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
        durationSeconds: map['duration_seconds'] as int? ?? 0,
        data: _decodeData(map['data'] as String? ?? '{}'),
      );

  static String _encodeData(Map<String, dynamic> data) {
    final buffer = StringBuffer('{');
    var first = true;
    data.forEach((key, value) {
      if (!first) buffer.write(',');
      buffer.write('"$key":"${value.toString().replaceAll('"', '\\"')}"');
      first = false;
    });
    buffer.write('}');
    return buffer.toString();
  }

  static Map<String, dynamic> _decodeData(String raw) {
    try {
      final result = <String, dynamic>{};
      final stripped = raw.trim().replaceAll(RegExp(r'^\{|\}$'), '');
      if (stripped.isEmpty) return result;
      for (final pair in stripped.split('","')) {
        final parts = pair.replaceAll('"', '').split(':');
        if (parts.length >= 2) {
          result[parts[0]] = parts.sublist(1).join(':');
        }
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  String get displayTitle {
    switch (type) {
      case 'app_usage':
        return data['app_name'] ?? data['package_name'] ?? 'App';
      case 'location':
        return data['place_name'] ?? data['address'] ?? 'Location';
      case 'activity':
        return data['activity'] ?? 'Activity';
      case 'screen':
        return data['state'] == 'on' ? 'Picked up phone' : 'Put down phone';
      case 'step':
        return '${data['steps'] ?? 0} steps';
      case 'wifi':
        return data['ssid'] ?? 'WiFi';
      case 'sleep':
        return 'Sleeping';
      case 'call':
        return data['contact'] ?? 'Phone call';
      default:
        return type;
    }
  }

  String get displayIcon {
    switch (type) {
      case 'app_usage':
        return '📱';
      case 'location':
        return '📍';
      case 'activity':
        final act = data['activity'] ?? '';
        if (act.contains('WALKING')) return '🚶';
        if (act.contains('RUNNING')) return '🏃';
        if (act.contains('IN_VEHICLE')) return '🚗';
        if (act.contains('ON_BICYCLE')) return '🚴';
        return '🧍';
      case 'screen':
        return data['state'] == 'on' ? '📲' : '💤';
      case 'step':
        return '👟';
      case 'wifi':
        return '📶';
      case 'sleep':
        return '😴';
      case 'call':
        return '📞';
      default:
        return '•';
    }
  }
}

/// Aggregated stats for a specific time period
class PeriodStats {
  final DateTime date;
  final int totalScreenTimeMinutes;
  final int totalSteps;
  final Map<String, int> appUsageMinutes; // packageName -> minutes
  final Map<String, int> locationMinutes; // place -> minutes
  final List<String> activities;
  final int phonePickups;
  final String? dominantActivity;

  PeriodStats({
    required this.date,
    required this.totalScreenTimeMinutes,
    required this.totalSteps,
    required this.appUsageMinutes,
    required this.locationMinutes,
    required this.activities,
    required this.phonePickups,
    this.dominantActivity,
  });

  String get productivityScore {
    final socialMinutes = _sumByCategory(['instagram', 'youtube', 'tiktok', 'facebook', 'twitter', 'snapchat']);
    final workMinutes = _sumByCategory(['notion', 'vscode', 'slack', 'gmail', 'docs', 'sheets']);
    final total = totalScreenTimeMinutes;
    if (total == 0) return 'N/A';
    final score = ((workMinutes / total) * 100).round();
    if (score >= 70) return 'Excellent';
    if (score >= 50) return 'Good';
    if (score >= 30) return 'Average';
    return 'Low';
  }

  int _sumByCategory(List<String> keywords) {
    int total = 0;
    appUsageMinutes.forEach((pkg, mins) {
      if (keywords.any((k) => pkg.toLowerCase().contains(k))) {
        total += mins;
      }
    });
    return total;
  }
}
