import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../ai/claude_service.dart';
import '../models/daily_summary.dart';
import '../utils/constants.dart';
import '../widgets/stat_card.dart';
import 'timeline_screen.dart';
import 'insights_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _db = DatabaseHelper();
  final _claude = ClaudeService();

  int _todaySteps = 0;
  int _screenTimeMinutes = 0;
  int _phonePickups = 0;
  Map<String, int> _appUsage = {};
  DailySummary? _todaySummary;
  bool _isGeneratingSummary = false;
  String _hourlyInsight = '';
  int _selectedNav = 0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();

    final stats = await _db.getDayStats(today);
    final appUsage = await _db.getAppUsageForDay(today);
    final summary = await _db.getDailySummary(today);

    if (!mounted) return;
    setState(() {
      _todaySteps = prefs.getInt('today_steps') ?? (stats['total_steps'] as int);
      _screenTimeMinutes = stats['total_screen_time_minutes'] as int;
      _phonePickups = prefs.getInt('today_pickups') ?? (stats['phone_pickups'] as int);
      _appUsage = appUsage;
      _todaySummary = summary;
    });

    // Load hourly insight
    if (summary != null) {
      setState(() {
        _hourlyInsight = summary.insights.split('\n').first;
      });
    }
  }

  Future<void> _generateSummary() async {
    setState(() => _isGeneratingSummary = true);
    try {
      final summary = await _claude.generateDailySummary(DateTime.now());
      await _db.saveDailySummary(summary);
      if (mounted) {
        setState(() {
          _todaySummary = summary;
          _isGeneratingSummary = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGeneratingSummary = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.tertiary,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _selectedNav,
        children: [
          _buildDashboard(),
          const TimelineScreen(),
          const InsightsScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: _buildNavBar(),
    );
  }

  Widget _buildDashboard() {
    final screenTimeHours = (_screenTimeMinutes / 60).toStringAsFixed(1);
    final now = DateTime.now();
    final greeting = _getGreeting(now.hour);

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      child: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 20,
                left: AppSizes.padding,
                right: AppSizes.padding,
                bottom: AppSizes.padding,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withAlpha(26),
                    AppColors.background,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            greeting,
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.primary,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('EEEE, MMM d').format(now),
                            style: AppTextStyles.title,
                          ),
                        ],
                      ),
                      // Live tracker dot
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.scoreHigh.withAlpha(26),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.scoreHigh.withAlpha(77),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: AppColors.scoreHigh,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.scoreHigh.withAlpha(128),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'TRACKING',
                                style: AppTextStyles.label.copyWith(
                                  color: AppColors.scoreHigh,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Stats grid
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.padding),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.1,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              delegate: SliverChildListDelegate([
                StatCard(
                  emoji: '📱',
                  label: 'SCREEN TIME',
                  value: '${screenTimeHours}h',
                  subtitle: '$_phonePickups pickups today',
                  color: _screenTimeMinutes > 240 ? AppColors.tertiary : AppColors.primary,
                ),
                StatCard(
                  emoji: '👟',
                  label: 'STEPS',
                  value: NumberFormat('#,###').format(_todaySteps),
                  subtitle: _todaySteps >= 10000
                      ? 'Goal reached!'
                      : '${10000 - _todaySteps} to goal',
                  color: _todaySteps >= 10000
                      ? AppColors.scoreHigh
                      : _todaySteps >= 5000
                          ? AppColors.scoreMid
                          : AppColors.tertiary,
                ),
                StatCard(
                  emoji: '🔄',
                  label: 'PICKUPS',
                  value: '$_phonePickups',
                  subtitle: _phonePickups > 80
                      ? 'Very distracted'
                      : _phonePickups > 40
                          ? 'Somewhat distracted'
                          : 'Good focus!',
                  color: _phonePickups > 80
                      ? AppColors.tertiary
                      : _phonePickups > 40
                          ? AppColors.scoreMid
                          : AppColors.scoreHigh,
                ),
                StatCard(
                  emoji: '🧠',
                  label: 'AI SCORE',
                  value: _todaySummary != null ? '${_todaySummary!.productivityScore}' : '--',
                  subtitle: _todaySummary?.productivityLabel ?? 'Tap to generate',
                  color: AppColors.secondary,
                  onTap: _todaySummary == null ? _generateSummary : null,
                ),
              ]),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: AppSizes.gapL)),

          // AI Summary card
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.padding),
            sliver: SliverToBoxAdapter(
              child: _buildAiSummaryCard(),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: AppSizes.gapM)),

          // App usage breakdown
          if (_appUsage.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.padding),
              sliver: SliverToBoxAdapter(
                child: _buildAppUsageCard(),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildAiSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(AppSizes.padding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withAlpha(30),
            AppColors.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        border: Border.all(color: AppColors.primary.withAlpha(51)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🤖', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                'AI DAILY BRIEF',
                style: AppTextStyles.label.copyWith(color: AppColors.primary),
              ),
              const Spacer(),
              if (_todaySummary != null)
                Row(
                  children: [
                    ScoreRing(
                      score: _todaySummary!.productivityScore,
                      label: 'FOCUS',
                      color: AppColors.secondary,
                      size: 48,
                    ),
                    const SizedBox(width: 12),
                    ScoreRing(
                      score: _todaySummary!.wellbeingScore,
                      label: 'WELL',
                      color: AppColors.scoreHigh,
                      size: 48,
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppSizes.gapM),
          if (_isGeneratingSummary)
            const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 12),
                  Text('Claude is analyzing your day...', style: AppTextStyles.body),
                ],
              ),
            )
          else if (_todaySummary != null) ...[
            Text(
              _todaySummary!.narrative,
              style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSizes.gapM),
            _buildInsightChip(_todaySummary!.recommendations.split('\n').first),
            const SizedBox(height: AppSizes.gapM),
            TextButton.icon(
              onPressed: _generateSummary,
              icon: const Icon(Icons.refresh, size: 16, color: AppColors.primary),
              label: Text(
                'Regenerate',
                style: AppTextStyles.label.copyWith(color: AppColors.primary),
              ),
            ),
          ] else
            Column(
              children: [
                Text(
                  'Tap below to get Claude\'s analysis of your day so far.',
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: AppSizes.gapM),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _generateSummary,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Analyze My Day ✨',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildInsightChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.secondary.withAlpha(26),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.secondary.withAlpha(77)),
      ),
      child: Row(
        children: [
          const Text('💡', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.body.copyWith(
                color: AppColors.secondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppUsageCard() {
    final topApps = _appUsage.entries.take(5).toList();
    final maxMinutes = topApps.isNotEmpty ? topApps.first.value : 1;

    final categoryColors = <String, Color>{};

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
          Row(
            children: [
              const Text('📱', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                'TOP APPS TODAY',
                style: AppTextStyles.label,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.gapM),
          ...topApps.asMap().entries.map((entry) {
            final idx = entry.key;
            final app = entry.value;
            final colors = [
              AppColors.social,
              AppColors.primary,
              AppColors.secondary,
              AppColors.scoreMid,
              AppColors.tertiary,
            ];
            return AppUsageBar(
              appName: app.key,
              minutes: app.value,
              maxMinutes: maxMinutes,
              color: colors[idx % colors.length],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                selected: _selectedNav == 0,
                onTap: () => setState(() => _selectedNav = 0),
              ),
              _NavItem(
                icon: Icons.timeline_rounded,
                label: 'Timeline',
                selected: _selectedNav == 1,
                onTap: () => setState(() => _selectedNav = 1),
              ),
              _NavItem(
                icon: Icons.auto_awesome_rounded,
                label: 'Insights',
                selected: _selectedNav == 2,
                onTap: () => setState(() => _selectedNav = 2),
              ),
              _NavItem(
                icon: Icons.settings_rounded,
                label: 'Settings',
                selected: _selectedNav == 3,
                onTap: () => setState(() => _selectedNav = 3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getGreeting(int hour) {
    if (hour < 5) return 'GOOD NIGHT';
    if (hour < 12) return 'GOOD MORNING';
    if (hour < 17) return 'GOOD AFTERNOON';
    if (hour < 21) return 'GOOD EVENING';
    return 'GOOD NIGHT';
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withAlpha(26) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: selected ? AppColors.primary : AppColors.textMuted,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.primary : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
