import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../models/chat_message.dart';

class LifeCoachService {
  static const _baseUrl = 'https://api.anthropic.com/v1/messages';
  static const _model = 'claude-sonnet-4-6';
  final _db = DatabaseHelper();

  Future<String?> _getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('claude_api_key');
  }

  /// Build the system prompt with all life data injected
  Future<String> _buildSystemPrompt() async {
    final today = DateTime.now();
    final stats = await _db.getDayStats(today);
    final recentSummaries = await _db.getRecentSummaries(7);

    final screenTimeHours = ((stats['total_screen_time_minutes'] as int) / 60).toStringAsFixed(1);
    final steps = stats['total_steps'] as int;
    final pickups = stats['phone_pickups'] as int;
    final appUsage = stats['app_usage'] as Map<String, int>;

    // Top apps
    final topApps = appUsage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topAppsStr = topApps.take(5)
        .map((e) => '${e.key}: ${e.value}min')
        .join(', ');

    // Recent day summaries
    String recentHistory = '';
    if (recentSummaries.isNotEmpty) {
      recentHistory = recentSummaries.take(5).map((s) {
        return '${s.date.day}/${s.date.month}: Productivity ${s.productivityScore}/100, Wellbeing ${s.wellbeingScore}/100. ${s.narrative.substring(0, s.narrative.length.clamp(0, 120))}...';
      }).join('\n');
    }

    // Calculate life score
    int lifeScore = 50;
    if (steps > 10000) lifeScore += 15;
    else if (steps > 5000) lifeScore += 8;
    final screenHoursDouble = double.tryParse(screenTimeHours) ?? 0;
    if (screenHoursDouble < 3) lifeScore += 15;
    else if (screenHoursDouble < 5) lifeScore += 8;
    else if (screenHoursDouble > 8) lifeScore -= 15;
    if (pickups < 50) lifeScore += 10;
    else if (pickups > 100) lifeScore -= 10;
    lifeScore = lifeScore.clamp(0, 100);

    return '''You are the LifeLens AI Coach — a personal life intelligence system and strategic thinking partner.

## YOUR ROLE
You are NOT a generic chatbot. You are a direct, data-driven personal coach who knows this person's actual daily patterns. You think like a mix of:
- A no-BS best friend who tells the truth
- A world-class productivity coach (like a mix of Cal Newport, Ali Abdaal)
- A sharp analyst who uses real numbers, not vague advice

## TODAY'S LIVE DATA (${today.day}/${today.month}/${today.year})
- Life Score: $lifeScore/100
- Screen Time: $screenTimeHours hours
- Phone Pickups: $pickups times
- Steps: $steps steps
- Top apps: $topAppsStr

## RECENT HISTORY (last 7 days)
$recentHistory

## CONVERSATION RULES — CRITICAL
1. ALWAYS be specific — use their actual numbers, not generic advice
2. ONE priority at a time. Never give 10 action items. One clear thing.
3. If they seem stressed or overwhelmed: acknowledge it first, then SIMPLIFY — tell them to ignore everything except ONE thing
4. Plans must be REALISTIC — if their steps are 500/day, don't say "run 5km tomorrow"
5. Be warm but direct. No fluff. No "Great question!"
6. When they ask about tomorrow/plans: give a SPECIFIC structured plan (time blocks if helpful)
7. Detect patterns across the 7-day history and point them out
8. "Less but better" — one sharp insight beats five vague ones
9. Never lecture. Coach.
10. End important responses with: 🎯 **ONE THING:** [the single most important action]

## ANTI-OVERWHELM PROTOCOL
If the user seems to be doing poorly (low steps + high screen time + high pickups for 3+ days):
- Don't pile on more goals
- Say: "Let's ignore everything else. Just ONE thing this week."
- Give them that ONE thing

## DAILY BRIEF FORMAT
When asked for daily brief or starting conversation, use this EXACT structure:

**⚡ LIFE SCORE: $lifeScore/100**

**📖 TODAY'S STORY**
[2-3 sentences about their actual day using real numbers. Make it feel personal.]

**✅ WORKING**
• [1-2 specific wins from today's data]

**⚠️ WATCH OUT**
• [1 specific concern based on data]

**🎯 TOMORROW'S ONE PRIORITY**
[One specific, achievable action. Not a list.]

**🗓 THIS WEEK'S THEME**
[One word or short phrase]

---
*Ask me anything — plans, patterns, what to do next, or just talk.*''';
  }

  /// Generate initial daily brief to start the conversation
  Future<String> generateDailyBrief() async {
    final systemPrompt = await _buildSystemPrompt();
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
        'max_tokens': 1024,
        'system': systemPrompt,
        'messages': [
          {'role': 'user', 'content': 'Give me my daily brief for today.'},
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('API error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final content = data['content'] as List<dynamic>;
    return (content.first as Map<String, dynamic>)['text'] as String;
  }

  /// Send a message and get a response, maintaining full conversation history
  Future<String> chat(List<ChatMessage> history, String userMessage) async {
    final systemPrompt = await _buildSystemPrompt();
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Claude API key not set. Go to Settings to add it.');
    }

    // Build message history for Claude (skip the daily brief assistant message for context efficiency, keep last 20)
    final messages = <Map<String, dynamic>>[];
    final relevantHistory = history.where((m) => !m.isDaily).toList();
    final recentHistory = relevantHistory.length > 20
        ? relevantHistory.sublist(relevantHistory.length - 20)
        : relevantHistory;

    for (final msg in recentHistory) {
      messages.add({'role': msg.role, 'content': msg.content});
    }
    messages.add({'role': 'user', 'content': userMessage});

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': _model,
        'max_tokens': 1536,
        'system': systemPrompt,
        'messages': messages,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('API error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final content = data['content'] as List<dynamic>;
    return (content.first as Map<String, dynamic>)['text'] as String;
  }
}
