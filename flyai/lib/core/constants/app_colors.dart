import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF2563EB);
  static const Color secondary = Color(0xFFF59E0B);
  static const Color background = Color(0xFF0F172A);
  static const Color card = Color(0xFF1E293B);
  static const Color surface = Color(0xFF1E293B);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFCBD5E1);
  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);

  // Glassmorphism
  static const Color glassLight = Color(0x1AFFFFFF);
  static const Color glassBorder = Color(0x33FFFFFF);

  // Swipe overlays
  static const Color swipeLike = Color(0xFF22C55E);
  static const Color swipeDislike = Color(0xFFEF4444);
  static const Color swipeSuperLike = Color(0xFF2563EB);

  // Gradient
  static const List<Color> primaryGradient = [
    Color(0xFF2563EB),
    Color(0xFF1D4ED8),
  ];

  static const List<Color> cardGradient = [
    Color(0xFF1E293B),
    Color(0xFF0F172A),
  ];
}
