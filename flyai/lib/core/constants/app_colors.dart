import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static bool isDark = false; // False = Light mode, True = Dark mode

  static Color get background => isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
  static Color get card => isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF);
  static Color get surface => isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF);
  static Color get textPrimary => isDark ? const Color(0xFFFFFFFF) : const Color(0xFF0F172A);
  static Color get textSecondary => isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B);

  static const Color primary = Color(0xFF2563EB);
  static const Color secondary = Color(0xFFF59E0B);
  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);

  // Glassmorphism
  static Color get glassLight => isDark ? const Color(0x1AFFFFFF) : const Color(0x0F000000);
  static Color get glassBorder => isDark ? const Color(0x33FFFFFF) : const Color(0x1F000000);

  // Swipe overlays
  static const Color swipeLike = Color(0xFF22C55E);
  static const Color swipeDislike = Color(0xFFEF4444);
  static const Color swipeSuperLike = Color(0xFF2563EB);

  // Gradient
  static List<Color> get primaryGradient => [
        const Color(0xFF2563EB),
        const Color(0xFF1D4ED8),
      ];

  static List<Color> get cardGradient => [
        isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF),
        isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      ];
}
