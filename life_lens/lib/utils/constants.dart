import 'package:flutter/material.dart';

// Light mode palette
const _lBackground    = Color(0xFFF0F0F7);
const _lSurface       = Color(0xFFFFFFFF);
const _lSurfaceVar    = Color(0xFFF8F8FC);
const _lNavBg         = Color(0xFF12122A);
const _lBorder        = Color(0xFFE8E8F0);
const _lTextPrimary   = Color(0xFF12122A);
const _lTextSecondary = Color(0xFF6B6B8A);
const _lTextMuted     = Color(0xFF9999B3);

// Dark mode palette
const _dBackground    = Color(0xFF0A0A14);
const _dSurface       = Color(0xFF13131F);
const _dSurfaceVar    = Color(0xFF1C1C2E);
const _dNavBg         = Color(0xFF07070F);
const _dBorder        = Color(0xFF252538);
const _dTextPrimary   = Color(0xFFF0F0FF);
const _dTextSecondary = Color(0xFFAAAACC);
const _dTextMuted     = Color(0xFF6666AA);

class AppColors {
  // Neon accent colors (same in both themes)
  static const neonGreen       = Color(0xFF39FF14);
  static const neonGreenDark   = Color(0xFF2ACC10);
  static const neonGreenLight  = Color(0xFF80FF50);
  static const neonPurple      = Color(0xFFD44DFF);
  static const neonPurpleDark  = Color(0xFF9900CC);
  static const tertiary        = Color(0xFFFF6B6B);

  // Score / category colors (same in both themes)
  static const scoreHigh       = Color(0xFF00C48C);
  static const scoreMid        = Color(0xFFFFB020);
  static const scoreLow        = Color(0xFFFF5252);
  static const social          = Color(0xFFFF6B9D);
  static const productive      = Color(0xFF00C48C);
  static const entertainment   = Color(0xFFFF9800);
  static const messaging       = Color(0xFF64B5F6);
  static const textOnDark      = Color(0xFFF0F0F8);
  static const textMutedDark   = Color(0xFF7070A0);

  // Theme-switchable colors — defaults to light
  static Color background    = _lBackground;
  static Color surface       = _lSurface;
  static Color surfaceVariant= _lSurfaceVar;
  static Color navBackground = _lNavBg;
  static Color border        = _lBorder;
  static Color primary       = neonGreen;
  static Color primaryDark   = neonGreenDark;
  static Color primaryLight  = neonGreenLight;
  static Color secondary     = neonPurple;
  static Color secondaryDark = neonPurpleDark;
  static Color textPrimary   = _lTextPrimary;
  static Color textSecondary = _lTextSecondary;
  static Color textMuted     = _lTextMuted;

  static bool isDark = false;

  static void setLight() {
    isDark = false;
    background     = _lBackground;
    surface        = _lSurface;
    surfaceVariant = _lSurfaceVar;
    navBackground  = _lNavBg;
    border         = _lBorder;
    textPrimary    = _lTextPrimary;
    textSecondary  = _lTextSecondary;
    textMuted      = _lTextMuted;
  }

  static void setDark() {
    isDark = true;
    background     = _dBackground;
    surface        = _dSurface;
    surfaceVariant = _dSurfaceVar;
    navBackground  = _dNavBg;
    border         = _dBorder;
    textPrimary    = _dTextPrimary;
    textSecondary  = _dTextSecondary;
    textMuted      = _dTextMuted;
  }
}

class AppTextStyles {
  static TextStyle get heroNumber => TextStyle(
    fontSize: 52,
    fontWeight: FontWeight.w900,
    color: AppColors.textPrimary,
    letterSpacing: -2,
  );

  static TextStyle get title => TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  static TextStyle get subtitle => TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static TextStyle get label => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textMuted,
    letterSpacing: 0.8,
  );

  static TextStyle get body => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.6,
  );
}

class AppSizes {
  static const cardRadius = 20.0;
  static const padding    = 20.0;
  static const gapS       = 8.0;
  static const gapM       = 16.0;
  static const gapL       = 24.0;
}
