import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../models/daily_summary.dart';
import '../services/usage_stats_service.dart';
import '../services/location_service.dart';

class ClaudeService {
  static const _baseUrl = 'https://api.anthropic.com/v1/messages';
  static const _model = 'claude-3-5-sonnet-20241022';

  final _db = DatabaseHelper();
  final _usageService = UsageStatsService();
  final _locationService = LifeLocationService();

  Future<String?> _getApiKey() async {
    const envKey = String.fromEnvironment('CLAUDE_API_KEY');
    if (envKey.isNotEmpty) return envKey;

    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('claude_api_key');
  }

  Future<String> _callClaude(String systemPrompt, String userMessage) async {
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Claude API key not set. Go to Settings to add it.');
    }

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': _model,
        'max_tokens': 2048,
        'system': systemPrompt,
        'messages': [
          {'role': 'user', 'content': userMessage},
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Claude API error: ${response.statusCode} - ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final content = data['content'] as List<dynamic>;
    return (content.first as Map<String, dynamic>)['text'] as String;
  }

  /// Generate a complete daily summary using Claude
  Future<DailySummary> generateDailySummary(DateTime day) async {
    final stats = await _db.getDayStats(day);
    final appUsageSummary = await _usageService.getDailyUsageSummary(day);
    final locationSummary = await _locationService.getLocationSummaryForDay(day);

    final screenTimeHours = ((stats['total_screen_time_minutes'] as int) / 60).toStringAsFixed(1);
    final steps = stats['total_steps'] as int;
    final pickups = stats['phone_pickups'] as int;
    final appUsage = stats['app_usage'] as Map<String, int>;

    // Calculate social vs productive time
    int socialMins = 0, productiveMins = 0;
    appUsage.forEach((app, mins) {
      final lower = app.toLowerCase();
      if (['instagram', 'youtube', 'tiktok', 'facebook', 'twitter', 'snapchat', 'reddit']
          .any(lower.contains)) {
        socialMins += mins;
      } else if (['notion', 'docs', 'sheets', 'slack', 'gmail', 'vscode', 'linkedin']
          .any(lower.contains)) {
        productiveMins += mins;
      }
    });

    final dataContext = '''
DATE: ${day.day}/${day.month}/${day.year} (${_dayName(day.weekday)})

SCREEN TIME: $screenTimeHours hours total
PHONE PICKUPS: $pickups times
STEPS: $steps steps

$appUsageSummary

LOCATION: $locationSummary

SOCIAL MEDIA TIME: ${socialMins}min
PRODUCTIVE APP TIME: ${productiveMins}min

Activities detected: ${(stats['activities'] as List).join(', ')}
''';

    final systemPrompt = '''You are LifeLens AI, a personal life coach and analyst.
You have access to someone's complete digital footprint for the day.
Be honest, insightful, and genuinely helpful - not preachy.
Write in a warm, direct, friend-like tone. Use specific numbers.
Keep the narrative engaging and personal.''';

    final userMessage = '''Analyze this person's day and generate:

$dataContext

Please respond with a JSON object in this exact format:
{
  "narrative": "A vivid 3-4 sentence story of their day using the data. Be specific with times and apps. Make it feel like you really know them.",
  "insights": "3-4 bullet points of key insights about patterns you see. Use specific numbers. Be honest about time wasted.",
  "recommendations": "3 specific, actionable things they can do tomorrow to improve. Make them practical.",
  "productivity_score": <0-100 integer based on productive vs social/entertainment time>,
  "wellbeing_score": <0-100 integer based on steps, screen time balance, activity variety>
}

Only respond with the JSON, nothing else.''';

    try {
      final response = await _callClaude(systemPrompt, userMessage);
      final cleanJson = response.trim().replaceAll('```json', '').replaceAll('```', '').trim();
      final parsed = jsonDecode(cleanJson) as Map<String, dynamic>;

      return DailySummary(
        date: DateTime(day.year, day.month, day.day),
        narrative: parsed['narrative'] as String? ?? '',
        insights: parsed['insights'] as String? ?? '',
        recommendations: parsed['recommendations'] as String? ?? '',
        productivityScore: (parsed['productivity_score'] as num?)?.toInt() ?? 50,
        wellbeingScore: (parsed['wellbeing_score'] as num?)?.toInt() ?? 50,
        rawStats: stats,
        generatedAt: DateTime.now(),
      );
    } catch (e) {
      // Return a basic summary if Claude fails
      return DailySummary(
        date: DateTime(day.year, day.month, day.day),
        narrative: 'You spent $screenTimeHours hours on your phone today with $steps steps walked.',
        insights: '• $screenTimeHours hours total screen time\n• $pickups phone pickups\n• $steps steps',
        recommendations: '• Try to reduce screen time\n• Walk more\n• Take breaks',
        productivityScore: 50,
        wellbeingScore: steps > 7500 ? 70 : 40,
        rawStats: stats,
        generatedAt: DateTime.now(),
      );
    }
  }

  /// Generate a real-time hourly insight
  Future<String> generateHourlyInsight(DateTime now) async {
    final events = await _db.getEventsForRange(
      now.subtract(const Duration(hours: 1)),
      now,
    );

    if (events.isEmpty) return "Quiet hour - no significant activity tracked.";

    final summary = events
        .take(20)
        .map((e) => '${e.displayIcon} ${e.displayTitle}')
        .join(', ');

    final systemPrompt = 'You are LifeLens AI. Give a single, punchy 1-sentence insight about the past hour of this person\'s life. Be direct and specific.';

    try {
      return await _callClaude(systemPrompt, 'Last hour: $summary. What\'s one sharp insight?');
    } catch (_) {
      return _generateOfflineInsight(events.length);
    }
  }

  /// Generate weekly pattern analysis
  Future<String> generateWeeklyReport() async {
    final summaries = await _db.getRecentSummaries(7);
    if (summaries.isEmpty) return 'Not enough data for weekly report yet.';

    final avgProductivity = summaries
            .map((s) => s.productivityScore)
            .reduce((a, b) => a + b) ~/
        summaries.length;

    final avgWellbeing = summaries
            .map((s) => s.wellbeingScore)
            .reduce((a, b) => a + b) ~/
        summaries.length;

    final narratives = summaries
        .map((s) => '${s.date.day}/${s.date.month}: ${s.narrative.substring(0, s.narrative.length.clamp(0, 100))}...')
        .join('\n');

    final systemPrompt = 'You are LifeLens AI analyzing a week of someone\'s life. Be insightful about patterns. Speak directly.';

    final userMessage = '''This person's week in brief:

$narratives

Average Productivity Score: $avgProductivity/100
Average Wellbeing Score: $avgWellbeing/100

Write a 3-4 sentence weekly pattern analysis. What story does this week tell? What patterns emerged? What should change next week?''';

    try {
      return await _callClaude(systemPrompt, userMessage);
    } catch (e) {
      return 'Weekly average - Productivity: $avgProductivity/100, Wellbeing: $avgWellbeing/100. Keep tracking for detailed insights.';
    }
  }

  String _generateOfflineInsight(int eventCount) {
    final insights = [
      'You\'ve had $eventCount tracked moments this hour.',
      'Active hour with $eventCount tracked events.',
      'Your phone is working hard with $eventCount events tracked.',
    ];
    return insights[eventCount % insights.length];
  }

  String _dayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[(weekday - 1) % 7];
  }
}
