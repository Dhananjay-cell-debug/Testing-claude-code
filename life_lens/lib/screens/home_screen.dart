import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'chat_screen.dart';

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
  int _selectedNav = 0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
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
          const CoachScreen(),
          const InsightsScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: _buildNavBar(),
    );
  }

  Widget _buildDashboard() {
    final now = DateTime.now();
    final greeting = _getGreeting(now.hour);
    final screenTimeHours = (_screenTimeMinutes / 60).toStringAsFixed(1);

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primaryDark,
      backgroundColor: AppColors.surface,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(greeting, now)),
          const SliverToBoxAdapter(child: SizedBox(height: AppSizes.gapM)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.padding),
            sliver: SliverToBoxAdapter(child: _buildHeroCard(screenTimeHours)),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.padding),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.05,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              delegate: SliverChildListDelegate([
                FluxStatCard(
                  label: 'Steps',
                  value: NumberFormat('#,###').format(_todaySteps),
                  badge: _todaySteps >= 10000
                      ? '+Goal!'
                      : '${((_todaySteps / 10000) * 100).toStringAsFixed(0)}%',
                  badgePositive: _todaySteps >= 5000,
                  icon: Icons.directions_walk_rounded,
                  color: AppColors.secondary,
                ),
                FluxStatCard(
                  label: 'Pickups',
                  value: '$_phonePickups',
                  badge: _phonePickups > 80
                      ? 'High'
                      : _phonePickups > 40
                          ? 'Mid'
                          : 'Low',
                  badgePositive: _phonePickups <= 40,
                  icon: Icons.phone_android_rounded,
                  color: _phonePickups > 80
                      ? AppColors.tertiary
                      : _phonePickups > 40
                          ? AppColors.scoreMid
                          : AppColors.scoreHigh,
                ),
                FluxStatCard(
                  label: 'AI Score',
                  value: _todaySummary != null
                      ? '${_todaySummary!.productivityScore}'
                      : '--',
                  badge: _todaySummary?.productivityLabel ?? 'Tap',
                  badgePositive: (_todaySummary?.productivityScore ?? 0) >= 60,
                  icon: Icons.auto_awesome_rounded,
                  color: AppColors.secondaryDark,
                  onTap: _todaySummary == null ? _generateSummary : null,
                ),
                FluxStatCard(
                  label: 'Wellbeing',
                  value: _todaySummary != null
                      ? '${_todaySummary!.wellbeingScore}%'
                      : '--',
                  badge: _todaySummary != null
                      ? (_todaySummary!.wellbeingScore >= 70 ? '+Good' : 'Check')
                      : 'Pending',
                  badgePositive: (_todaySummary?.wellbeingScore ?? 0) >= 70,
                  icon: Icons.favorite_rounded,
                  color: AppColors.scoreHigh,
                ),
              ]),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          if (_appUsage.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.padding),
              sliver: SliverToBoxAdapter(child: _buildActivityCard()),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.padding),
            sliver: SliverToBoxAdapter(child: _buildAiBriefCard()),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildHeader(String greeting, DateTime now) {
    return Container(
      color: AppColors.background,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: AppSizes.padding,
        right: AppSizes.padding,
        bottom: 12,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.secondary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                'LL',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.secondaryDark,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  DateFormat('EEEE, MMM d').format(now),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'LIVE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(String screenTimeHours) {
    final screenDouble = double.tryParse(screenTimeHours) ?? 0.0;
    final dailyMax = 10.0;
    final pickupFrac = (_phonePickups / 150.0).clamp(0.0, 1.0);
    final screenFrac = (screenDouble / dailyMax).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(AppSizes.padding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.phone_android_rounded,
                      size: 18, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    'Screen Time',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  screenDouble > 6 ? 'High' : screenDouble > 3 ? 'Avg' : '+Low',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                screenTimeHours,
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -3,
                  height: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 4),
                child: Text(
                  'hrs today',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 110,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  child: _buildBubble(
                    size: 100,
                    color: AppColors.secondary,
                    label: '${screenTimeHours}h',
                    sublabel: 'screen',
                  ),
                ),
                Positioned(
                  left: 75,
                  top: 15,
                  child: _buildBubble(
                    size: 80,
                    color: AppColors.textPrimary,
                    label: '$_phonePickups',
                    sublabel: 'picks',
                  ),
                ),
                Positioned(
                  left: 148,
                  top: 35,
                  child: _buildBubble(
                    size: 62,
                    color: AppColors.primary,
                    label: '${(_todaySteps / 1000).toStringAsFixed(1)}k',
                    sublabel: 'steps',
                    textDark: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildMiniProgress('Screen Time', screenFrac,
              '${screenTimeHours}h / ${dailyMax.toInt()}h', AppColors.secondary),
          const SizedBox(height: 8),
          _buildMiniProgress('Phone Pickups', pickupFrac,
              '$_phonePickups / 150', AppColors.textPrimary),
          const SizedBox(height: 8),
          _buildMiniProgress(
            'Step Goal',
            (_todaySteps / 10000.0).clamp(0.0, 1.0),
            '${NumberFormat('#,###').format(_todaySteps)} / 10,000',
            AppColors.primary,
            textDark: true,
          ),
        ],
      ),
    );
  }

  Widget _buildBubble({
    required double size,
    required Color color,
    required String label,
    required String sublabel,
    bool textDark = false,
  }) {
    final textColor = textDark ? AppColors.primaryDark : Colors.white;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: size * 0.22,
              fontWeight: FontWeight.w900,
              color: textColor,
              height: 1,
            ),
          ),
          Text(
            sublabel,
            style: TextStyle(
              fontSize: size * 0.14,
              fontWeight: FontWeight.w500,
              color: textColor.withAlpha(180),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniProgress(
      String label, double value, String trailing, Color color,
      {bool textDark = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            Text(
              trailing,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: textDark ? AppColors.primaryDark : color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: value,
            backgroundColor: color.withAlpha(40),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildActivityCard() {
    final topApps = _appUsage.entries.take(4).toList();
    final maxMinutes = topApps.isNotEmpty ? topApps.first.value : 1;
    final barColors = [
      AppColors.secondary,
      AppColors.secondaryDark,
      AppColors.scoreMid,
      AppColors.tertiary,
    ];

    return Container(
      padding: const EdgeInsets.all(AppSizes.padding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.grid_view_rounded,
                  size: 18, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                'Top Apps Today',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary),
              ),
              const Spacer(),
              Text('${topApps.length} apps',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: AppSizes.gapM),
          ...topApps.asMap().entries.map((entry) {
            final app = entry.value;
            final color = barColors[entry.key % barColors.length];
            final frac = maxMinutes > 0 ? app.value / maxMinutes : 0.0;
            final h = app.value ~/ 60;
            final m = app.value % 60;
            final timeStr = h > 0 ? '${h}h ${m}m' : '${m}m';
            final pct = ((app.value /
                        (_screenTimeMinutes > 0 ? _screenTimeMinutes : 1)) *
                    100)
                .toStringAsFixed(0);

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(app.key,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      Row(
                        children: [
                          Text(timeStr,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: color)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withAlpha(30),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('$pct%',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: color)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: frac.clamp(0.0, 1.0),
                      backgroundColor: color.withAlpha(30),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAiBriefCard() {
    return Container(
      padding: const EdgeInsets.all(AppSizes.padding),
      decoration: BoxDecoration(
        color: AppColors.navBackground,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(40),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.auto_awesome_rounded,
                    size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Text(
                'AI Daily Brief',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textOnDark),
              ),
              const Spacer(),
              if (_todaySummary != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(40),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Today',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSizes.gapM),
          if (_todaySummary != null) ...[
            Row(
              children: [
                _buildDarkStat('${_todaySummary!.productivityScore}',
                    'Focus Score', AppColors.primary),
                const SizedBox(width: 24),
                _buildDarkStat('${_todaySummary!.wellbeingScore}%',
                    'Wellbeing', AppColors.secondary),
              ],
            ),
            const SizedBox(height: AppSizes.gapM),
            _buildMiniBarChart(),
            const SizedBox(height: AppSizes.gapM),
            Text(
              _todaySummary!.narrative,
              style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textMutedDark,
                  height: 1.5),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _generateSummary,
              child: Row(
                children: [
                  Icon(Icons.refresh_rounded,
                      size: 14, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text('Regenerate',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary)),
                ],
              ),
            ),
          ] else if (_isGeneratingSummary) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    const SizedBox(height: 12),
                    Text('Claude is analyzing your day...',
                        style: TextStyle(
                            color: AppColors.textMutedDark, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ] else ...[
            Text(
              'Get Claude\'s analysis of your day',
              style: TextStyle(
                  fontSize: 13, color: AppColors.textMutedDark, height: 1.5),
            ),
            const SizedBox(height: AppSizes.gapM),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _generateSummary,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.primaryDark,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text(
                  'Analyze My Day',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDarkStat(String value, String label, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 18,
              decoration:
                  BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 8),
            Text(
              value,
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textOnDark,
                  letterSpacing: -1),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 11),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMutedDark,
                  fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }

  Widget _buildMiniBarChart() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final todayIdx = DateTime.now().weekday - 1;
    final heights = [0.4, 0.6, 0.5, 0.7, 0.45, 0.3, 0.0];
    heights[todayIdx] = (_screenTimeMinutes / (10 * 60)).clamp(0.1, 1.0);

    return SizedBox(
      height: 70,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: days.asMap().entries.map((e) {
          final isToday = e.key == todayIdx;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    height: 48 * heights[e.key],
                    decoration: BoxDecoration(
                      color: isToday
                          ? AppColors.primary
                          : AppColors.secondary.withAlpha(60),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    e.value,
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: isToday
                            ? AppColors.primary
                            : AppColors.textMutedDark),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.navBackground,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(40),
              blurRadius: 20,
              offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _FluxNavItem(
                icon: Icons.grid_view_rounded,
                label: 'Dashboard',
                selected: _selectedNav == 0,
                onTap: () => setState(() => _selectedNav = 0),
              ),
              _FluxNavItem(
                icon: Icons.timeline_rounded,
                label: 'Timeline',
                selected: _selectedNav == 1,
                onTap: () => setState(() => _selectedNav = 1),
              ),
              _FluxNavItem(
                icon: Icons.psychology_rounded,
                label: 'Coach',
                selected: _selectedNav == 2,
                onTap: () => setState(() => _selectedNav = 2),
              ),
              _FluxNavItem(
                icon: Icons.auto_awesome_rounded,
                label: 'Insights',
                selected: _selectedNav == 3,
                onTap: () => setState(() => _selectedNav = 3),
              ),
              _FluxNavItem(
                icon: Icons.settings_rounded,
                label: 'Settings',
                selected: _selectedNav == 4,
                onTap: () => setState(() => _selectedNav = 4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getGreeting(int hour) {
    if (hour < 5) return 'Good Night';
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    if (hour < 21) return 'Good Evening';
    return 'Good Night';
  }
}

class _FluxNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FluxNavItem({
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
          color:
              selected ? AppColors.primary.withAlpha(30) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: selected ? AppColors.primary : AppColors.textMutedDark,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color:
                    selected ? AppColors.primary : AppColors.textMutedDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
