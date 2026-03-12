/// AI-generated daily summary stored locally
class DailySummary {
  final int? id;
  final DateTime date;
  final String narrative; // Claude's written narrative
  final String insights; // Key insights
  final String recommendations; // What to improve
  final int productivityScore; // 0-100
  final int wellbeingScore; // 0-100
  final Map<String, dynamic> rawStats;
  final DateTime generatedAt;

  DailySummary({
    this.id,
    required this.date,
    required this.narrative,
    required this.insights,
    required this.recommendations,
    required this.productivityScore,
    required this.wellbeingScore,
    required this.rawStats,
    required this.generatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date.millisecondsSinceEpoch,
        'narrative': narrative,
        'insights': insights,
        'recommendations': recommendations,
        'productivity_score': productivityScore,
        'wellbeing_score': wellbeingScore,
        'raw_stats': _encodeMap(rawStats),
        'generated_at': generatedAt.millisecondsSinceEpoch,
      };

  static DailySummary fromMap(Map<String, dynamic> map) => DailySummary(
        id: map['id'] as int?,
        date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
        narrative: map['narrative'] as String? ?? '',
        insights: map['insights'] as String? ?? '',
        recommendations: map['recommendations'] as String? ?? '',
        productivityScore: map['productivity_score'] as int? ?? 0,
        wellbeingScore: map['wellbeing_score'] as int? ?? 0,
        rawStats: {},
        generatedAt: DateTime.fromMillisecondsSinceEpoch(
          map['generated_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
        ),
      );

  static String _encodeMap(Map<String, dynamic> map) {
    return map.entries.map((e) => '${e.key}=${e.value}').join('|');
  }

  String get productivityLabel {
    if (productivityScore >= 80) return 'Outstanding';
    if (productivityScore >= 60) return 'Good';
    if (productivityScore >= 40) return 'Average';
    if (productivityScore >= 20) return 'Below Average';
    return 'Poor';
  }

  String get wellbeingLabel {
    if (wellbeingScore >= 80) return 'Thriving';
    if (wellbeingScore >= 60) return 'Balanced';
    if (wellbeingScore >= 40) return 'Neutral';
    if (wellbeingScore >= 20) return 'Stressed';
    return 'Struggling';
  }
}

/// Weekly aggregated intelligence
class WeeklyReport {
  final DateTime weekStart;
  final List<DailySummary> dailySummaries;
  final String weeklyNarrative;
  final List<String> patterns; // Patterns detected across the week
  final List<String> improvements; // What improved vs last week
  final List<String> warnings; // What got worse
  final Map<String, int> topApps; // Most used apps this week
  final int avgProductivityScore;
  final int totalSteps;
  final int totalScreenTimeHours;

  WeeklyReport({
    required this.weekStart,
    required this.dailySummaries,
    required this.weeklyNarrative,
    required this.patterns,
    required this.improvements,
    required this.warnings,
    required this.topApps,
    required this.avgProductivityScore,
    required this.totalSteps,
    required this.totalScreenTimeHours,
  });
}
