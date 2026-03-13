import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../database/database_helper.dart';
import '../ai/claude_service.dart';
import '../models/daily_summary.dart';
import '../utils/constants.dart';
import '../widgets/stat_card.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> with SingleTickerProviderStateMixin {
  final _db = DatabaseHelper();
  final _claude = ClaudeService();

  List<DailySummary> _recentSummaries = [];
  String _weeklyReport = '';
  bool _loadingReport = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final summaries = await _db.getRecentSummaries(7);
    setState(() => _recentSummaries = summaries);
  }

  Future<void> _generateWeeklyReport() async {
    setState(() => _loadingReport = true);
    try {
      final report = await _claude.generateWeeklyReport();
      setState(() {
        _weeklyReport = report;
        _loadingReport = false;
      });
    } catch (e) {
      setState(() => _loadingReport = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.tertiary),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.primary,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: AppTextStyles.label.copyWith(fontSize: 11),
            tabs: const [
              Tab(text: 'TRENDS'),
              Tab(text: 'PATTERNS'),
              Tab(text: 'WEEKLY AI'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTrendsTab(),
                _buildPatternsTab(),
                _buildWeeklyAiTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: AppSizes.padding,
        right: AppSizes.padding,
        bottom: 12,
      ),
      child: Row(
        children: [
          Text('INSIGHTS', style: AppTextStyles.label.copyWith(color: AppColors.primary, fontSize: 14)),
          const Spacer(),
          Text('Last 7 days', style: AppTextStyles.label),
        ],
      ),
    );
  }

  Widget _buildTrendsTab() {
    if (_recentSummaries.isEmpty) {
      return _buildNoDataState('Generate daily summaries to see your trends');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildScoreChart(),
          const SizedBox(height: AppSizes.gapL),
          _buildAveragesRow(),
          const SizedBox(height: AppSizes.gapL),
          _buildDailySummaryList(),
        ],
      ),
    );
  }

  Widget _buildScoreChart() {
    final spots7Day = _recentSummaries.reversed.take(7).toList();

    return Container(
      padding: const EdgeInsets.all(AppSizes.padding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SCORE TRENDS', style: AppTextStyles.label),
          const SizedBox(height: AppSizes.gapM),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.border,
                    strokeWidth: 0.5,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toInt()}',
                        style: AppTextStyles.label.copyWith(fontSize: 9),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= spots7Day.length) return const SizedBox.shrink();
                        final day = spots7Day[idx].date;
                        return Text(
                          '${day.day}/${day.month}',
                          style: AppTextStyles.label.copyWith(fontSize: 9),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minY: 0,
                maxY: 100,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots7Day.asMap().entries.map((e) {
                      return FlSpot(e.key.toDouble(), e.value.productivityScore.toDouble());
                    }).toList(),
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary.withAlpha(26),
                    ),
                  ),
                  LineChartBarData(
                    spots: spots7Day.asMap().entries.map((e) {
                      return FlSpot(e.key.toDouble(), e.value.wellbeingScore.toDouble());
                    }).toList(),
                    isCurved: true,
                    color: AppColors.secondary,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.secondary.withAlpha(26),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _legendDot(AppColors.primary, 'Productivity'),
              const SizedBox(width: 16),
              _legendDot(AppColors.secondary, 'Wellbeing'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.label),
      ],
    );
  }

  Widget _buildAveragesRow() {
    if (_recentSummaries.isEmpty) return const SizedBox.shrink();

    final avgProd = _recentSummaries.map((s) => s.productivityScore).reduce((a, b) => a + b) ~/
        _recentSummaries.length;
    final avgWell = _recentSummaries.map((s) => s.wellbeingScore).reduce((a, b) => a + b) ~/
        _recentSummaries.length;

    return Row(
      children: [
        Expanded(
          child: StatCard(
            emoji: '🧠',
            label: '7-DAY AVG FOCUS',
            value: '$avgProd',
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatCard(
            emoji: '💚',
            label: '7-DAY AVG WELL',
            value: '$avgWell',
            color: AppColors.secondary,
          ),
        ),
      ],
    );
  }

  Widget _buildDailySummaryList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('DAILY SUMMARIES', style: AppTextStyles.label),
        const SizedBox(height: AppSizes.gapM),
        ..._recentSummaries.map((s) => _DailySummaryCard(summary: s)),
      ],
    );
  }

  Widget _buildPatternsTab() {
    if (_recentSummaries.isEmpty) {
      return _buildNoDataState('Need at least 3 days of data to detect patterns');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPatternCard(
            '🌅',
            'BEST PRODUCTIVE DAY',
            _getBestDay(),
            AppColors.scoreHigh,
          ),
          const SizedBox(height: AppSizes.gapM),
          _buildPatternCard(
            '📉',
            'WORST DAY THIS WEEK',
            _getWorstDay(),
            AppColors.tertiary,
          ),
          const SizedBox(height: AppSizes.gapM),
          _buildPatternCard(
            '📈',
            'TREND',
            _getTrend(),
            AppColors.primary,
          ),
          const SizedBox(height: AppSizes.gapM),
          _buildStreakCard(),
        ],
      ),
    );
  }

  Widget _buildPatternCard(String emoji, String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.padding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        border: Border.all(color: color.withAlpha(51)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.label),
                const SizedBox(height: 4),
                Text(value, style: AppTextStyles.body.copyWith(color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakCard() {
    int streak = 0;
    for (final s in _recentSummaries) {
      if (s.productivityScore >= 50) {
        streak++;
      } else {
        break;
      }
    }

    return Container(
      padding: const EdgeInsets.all(AppSizes.padding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.scoreMid.withAlpha(30), AppColors.surface],
        ),
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        border: Border.all(color: AppColors.scoreMid.withAlpha(77)),
      ),
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 40)),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PRODUCTIVITY STREAK', style: AppTextStyles.label),
              const SizedBox(height: 4),
              Text(
                '$streak day${streak != 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: AppColors.scoreMid,
                ),
              ),
              Text(
                streak > 0 ? 'Keep it up!' : 'Start your streak today',
                style: AppTextStyles.body,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyAiTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.padding),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary.withAlpha(30), AppColors.surface],
              ),
              borderRadius: BorderRadius.circular(AppSizes.cardRadius),
              border: Border.all(color: AppColors.primary.withAlpha(51)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('🤖', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 8),
                    Text('WEEKLY INTELLIGENCE REPORT',
                        style: AppTextStyles.label.copyWith(color: AppColors.primary)),
                  ],
                ),
                const SizedBox(height: AppSizes.gapM),
                if (_loadingReport)
                  Column(
                    children: [
                      CircularProgressIndicator(color: AppColors.primary),
                      const SizedBox(height: 12),
                      Text('Claude is analyzing your week...', style: AppTextStyles.body),
                    ],
                  )
                else if (_weeklyReport.isNotEmpty)
                  Text(_weeklyReport, style: AppTextStyles.body.copyWith(color: AppColors.textPrimary))
                else
                  Column(
                    children: [
                      Text(
                        'Get a deep AI analysis of your entire week - patterns, improvements, and what to change.',
                        style: AppTextStyles.body,
                      ),
                      const SizedBox(height: AppSizes.gapM),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _recentSummaries.isEmpty ? null : _generateWeeklyReport,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Generate Weekly Report ✨',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                      if (_recentSummaries.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Generate at least one daily summary first.',
                            style: AppTextStyles.body.copyWith(color: AppColors.tertiary, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                if (_weeklyReport.isNotEmpty) ...[
                  const SizedBox(height: AppSizes.gapM),
                  TextButton.icon(
                    onPressed: _generateWeeklyReport,
                    icon: Icon(Icons.refresh, size: 16, color: AppColors.primary),
                    label: Text('Refresh', style: AppTextStyles.label.copyWith(color: AppColors.primary)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📊', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text('No data yet', style: AppTextStyles.subtitle),
          const SizedBox(height: 8),
          Text(message, style: AppTextStyles.body, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  String _getBestDay() {
    if (_recentSummaries.isEmpty) return 'No data';
    final best = _recentSummaries.reduce((a, b) => a.productivityScore > b.productivityScore ? a : b);
    return '${_dayName(best.date.weekday)} - Score: ${best.productivityScore}';
  }

  String _getWorstDay() {
    if (_recentSummaries.isEmpty) return 'No data';
    final worst = _recentSummaries.reduce((a, b) => a.productivityScore < b.productivityScore ? a : b);
    return '${_dayName(worst.date.weekday)} - Score: ${worst.productivityScore}';
  }

  String _getTrend() {
    if (_recentSummaries.length < 2) return 'Need more data';
    final recent = _recentSummaries.take(3).map((s) => s.productivityScore).reduce((a, b) => a + b) ~/ 3;
    final older = _recentSummaries.skip(3).map((s) => s.productivityScore).reduce((a, b) => a + b) ~/
        (_recentSummaries.length - 3).clamp(1, 999);
    if (recent > older + 5) return '📈 Improving ($recent vs $older avg)';
    if (recent < older - 5) return '📉 Declining ($recent vs $older avg)';
    return '➡️ Steady ($recent avg this week)';
  }

  String _dayName(int weekday) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[(weekday - 1) % 7];
  }
}

class _DailySummaryCard extends StatelessWidget {
  final DailySummary summary;

  const _DailySummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(AppSizes.padding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${summary.date.day}/${summary.date.month}/${summary.date.year}',
                style: AppTextStyles.label,
              ),
              const Spacer(),
              ScoreRing(score: summary.productivityScore, label: '', color: AppColors.primary, size: 36),
              const SizedBox(width: 8),
              ScoreRing(score: summary.wellbeingScore, label: '', color: AppColors.secondary, size: 36),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            summary.narrative,
            style: AppTextStyles.body,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
