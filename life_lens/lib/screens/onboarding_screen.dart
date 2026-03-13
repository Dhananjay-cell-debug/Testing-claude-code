import 'package:flutter/material.dart';
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
  ];

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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _currentPage = i),
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
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_currentPage < _pages.length - 1) {
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
                      _currentPage < _pages.length - 1 ? 'Continue' : 'Start Tracking My Life →',
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
