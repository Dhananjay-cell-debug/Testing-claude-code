import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/background_service.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'utils/constants.dart';

final themeNotifier = ValueNotifier<bool>(false); // false = light

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load saved theme
  final prefs = await SharedPreferences.getInstance();
  final savedDark = prefs.getBool('dark_mode') ?? false;
  if (savedDark) {
    AppColors.setDark();
    themeNotifier.value = true;
  }

  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: savedDark ? Brightness.light : Brightness.dark,
    systemNavigationBarColor: AppColors.surface,
    systemNavigationBarIconBrightness: savedDark ? Brightness.light : Brightness.dark,
  ));

  await setupNotificationChannel();
  await initializeBackgroundService();

  runApp(const LifeLensApp());
}

class LifeLensApp extends StatelessWidget {
  const LifeLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: themeNotifier,
      builder: (context, isDark, _) {
        return MaterialApp(
          title: 'LifeLens',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: AppColors.primary,
                    secondary: AppColors.secondary,
                    surface: AppColors.surface,
                    onPrimary: Colors.black,
                    onSecondary: Colors.black,
                    onSurface: AppColors.textPrimary,
                  )
                : ColorScheme.light(
                    primary: AppColors.primary,
                    secondary: AppColors.secondary,
                    surface: AppColors.surface,
                    onPrimary: Colors.black,
                    onSecondary: Colors.black,
                    onSurface: AppColors.textPrimary,
                  ),
            scaffoldBackgroundColor: AppColors.background,
            fontFamily: 'Inter',
            appBarTheme: AppBarTheme(
              backgroundColor: AppColors.background,
              foregroundColor: AppColors.textPrimary,
              elevation: 0,
            ),
            snackBarTheme: SnackBarThemeData(
              backgroundColor: AppColors.surface,
              contentTextStyle: TextStyle(color: AppColors.textPrimary),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              behavior: SnackBarBehavior.floating,
            ),
          ),
          home: const _AppEntry(),
        );
      },
    );
  }
}

class _AppEntry extends StatefulWidget {
  const _AppEntry();

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  bool? _onboardingComplete;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool('onboarding_complete') ?? false;
    setState(() => _onboardingComplete = done);
  }

  @override
  Widget build(BuildContext context) {
    if (_onboardingComplete == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (!_onboardingComplete!) {
      return OnboardingScreen(
        onComplete: () => setState(() => _onboardingComplete = true),
      );
    }

    return const HomeScreen();
  }
}
