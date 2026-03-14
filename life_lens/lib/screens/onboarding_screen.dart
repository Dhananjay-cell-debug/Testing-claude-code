import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  bool _usageGranted = false;
  static const _nativeChannel = MethodChannel('com.dhananjay.lifelens/native');

  // Page 4 (index 4) is the Usage Access page
  static const int _usagePageIndex = 4;

  final _pages = [
    _OnboardingPage(
      emoji: '🧠',
      title: 'Your Life, Quantified',
      subtitle: 'LifeLens tracks every minute of your day and turns it into actionable intelligence.',
      color: AppColors.primary,
    ),
    _OnboardingPage(
      emoji: '📱',
      title: 'Every App, Every Moment',
      subtitle: 'See exactly where your time goes. Every app session, every distraction, every productive block.',
      color: AppColors.secondary,
    ),
    _OnboardingPage(
      emoji: '📍',
      title: 'Know Where You Are',
      subtitle: 'Track where you spend your time. Home, office, gym, or somewhere new.',
      color: AppColors.scoreMid,
    ),
    _OnboardingPage(
      emoji: '🤖',
      title: 'AI That Knows You',
      subtitle: 'Claude AI analyzes all your data and gives you a brutally honest, deeply personal daily brief.',
      color: AppColors.tertiary,
    ),
    _OnboardingPage(
      emoji: '📊',
      title: 'One Critical Permission',
      subtitle: 'Usage Access lets LifeLens see which apps you use and for how long. Without it, screen time stays zero.',
      color: const Color(0xFFFF6B35),
    ),
  ];

  Future<void> _checkUsageAccess() async {
    try {
      final granted = await _nativeChannel.invokeMethod<bool>('hasUsageAccessPermission') ?? false;
      if (mounted) setState(() => _usageGranted = granted);
    } catch (_) {}
  }

  Future<void> _openUsageAccess() async {
    try {
      await _nativeChannel.invokeMethod('openUsageAccessSettings');
      // Wait a moment then re-check
      await Future.delayed(const Duration(seconds: 2));
      await _checkUsageAccess();
    } catch (_) {}
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.location,
      Permission.activityRecognition,
      Permission.notification,
    ].request();
  }

  Future<void> _completeOnboarding() async {
    await _requestPermissions();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    widget.onComplete();
  }

  @override
  void initState() {
    super.initState();
    _checkUsageAccess();
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _pages.length - 1;
    final isUsagePage = _currentPage == _usagePageIndex;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (i) {
                setState(() => _currentPage = i);
                if (i == _usagePageIndex) _checkUsageAccess();
              },
              itemCount: _pages.length,
              itemBuilder: (context, index) => _pages[index],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSizes.padding),
            child: Column(
              children: [
                // Dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pages.length, (i) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _currentPage ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _currentPage ? AppColors.primary : AppColors.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: AppSizes.gapL),

                // Usage Access grant button (only on usage page and not yet granted)
                if (isUsagePage && !_usageGranted) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openUsageAccess,
                      icon: const Icon(Icons.lock_open_rounded, size: 18),
                      label: const Text(
                        'Grant Usage Access',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B35),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                if (isUsagePage && _usageGranted) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.scoreHigh.withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, color: AppColors.scoreHigh, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Usage Access granted!',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.scoreHigh,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (!isLastPage) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        _completeOnboarding();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      isLastPage
                          ? 'Start Tracking My Life →'
                          : isUsagePage && !_usageGranted
                              ? 'Skip for Now'
                              : 'Continue',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SafeArea(
                  child: Text(
                    'All data stays on your device.',
                    style: AppTextStyles.body.copyWith(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;

  const _OnboardingPage({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.padding * 1.5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: color.withAlpha(26),
              shape: BoxShape.circle,
              border: Border.all(color: color.withAlpha(77), width: 2),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 52)),
            ),
          ),
          const SizedBox(height: 40),
          Text(
            title,
            style: AppTextStyles.title.copyWith(fontSize: 30),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            subtitle,
            style: AppTextStyles.subtitle.copyWith(height: 1.6),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
