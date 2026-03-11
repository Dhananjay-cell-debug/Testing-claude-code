import 'package:flutter/material.dart';

class AppColors {
  // Dark theme base
  static const background = Color(0xFF0A0A0F);
  static const surface = Color(0xFF14141F);
  static const surfaceVariant = Color(0xFF1E1E2E);
  static const border = Color(0xFF2A2A3A);

  // Accent colors
  static const primary = Color(0xFF6C63FF); // Deep purple
  static const primaryLight = Color(0xFF9C8FFF);
  static const secondary = Color(0xFF00D4AA); // Teal
  static const tertiary = Color(0xFFFF6B6B); // Coral red

  // Score colors
  static const scoreHigh = Color(0xFF00E676); // Green
  static const scoreMid = Color(0xFFFFD740); // Amber
  static const scoreLow = Color(0xFFFF5252); // Red

  // Category colors
  static const social = Color(0xFFFF6B9D); // Pink
  static const productive = Color(0xFF00D4AA); // Teal
  static const entertainment = Color(0xFFFF9800); // Orange
  static const messaging = Color(0xFF64B5F6); // Blue

  // Text
  static const textPrimary = Color(0xFFF0F0F8);
  static const textSecondary = Color(0xFF9090A8);
  static const textMuted = Color(0xFF5A5A72);
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
    fontWeight: FontWeight.w700,
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
