import 'package:flutter/material.dart';

class AppColors {
  // Light theme base (Flux style)
  static const background = Color(0xFFF0F0F7);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF8F8FC);
  static const navBackground = Color(0xFF12122A); // Dark nav
  static const surfaceVariant = Color(0xFFF0F0F8);
  static const border = Color(0xFFE8E8F0);

  // Accent colors
  static const primary = Color(0xFFC5F135);       // Lime green (Flux style)
  static const primaryDark = Color(0xFF9DC200);
  static const primaryLight = Color(0xFFDDFF70); // Light lime
  static const secondary = Color(0xFFB4AEFF);     // Lavender purple
  static const secondaryDark = Color(0xFF6C63FF);
  static const tertiary = Color(0xFFFF6B6B);      // Coral red

  // Score colors
  static const scoreHigh = Color(0xFF00C48C);
  static const scoreMid = Color(0xFFFFB020);
  static const scoreLow = Color(0xFFFF5252);

  // Category colors
  static const social = Color(0xFFFF6B9D);
  static const productive = Color(0xFF00C48C);
  static const entertainment = Color(0xFFFF9800);
  static const messaging = Color(0xFF64B5F6);

  // Text
  static const textPrimary = Color(0xFF12122A);
  static const textSecondary = Color(0xFF6B6B8A);
  static const textMuted = Color(0xFF9999B3);
  static const textOnDark = Color(0xFFF0F0F8);
  static const textMutedDark = Color(0xFF7070A0);
}

class AppTextStyles {
  static const heroNumber = TextStyle(
    fontSize: 52,
    fontWeight: FontWeight.w900,
    color: AppColors.textPrimary,
    letterSpacing: -2,
  );

  static const title = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  static const subtitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static const label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textMuted,
    letterSpacing: 0.8,
  );

  static const body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.6,
  );
}

class AppSizes {
  static const cardRadius = 20.0;
  static const padding = 20.0;
  static const gapS = 8.0;
  static const gapM = 16.0;
  static const gapL = 24.0;
}
