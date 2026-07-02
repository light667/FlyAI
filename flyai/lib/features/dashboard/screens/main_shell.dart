import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../swipe/screens/swipe_screen.dart';
import 'community_feed_screen.dart';
import '../../ai_assistant/screens/ai_assistant_screen.dart';
import '../../applications/screens/applications_screen.dart';
import '../../profile/screens/profile_screen.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});
  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;

  static const _screens = [
    SwipeScreen(),
    CommunityFeedScreen(),
    AiAssistantScreen(),
    ApplicationsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: _FlyNavBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

class _FlyNavBar extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;
  const _FlyNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: 66,
            decoration: BoxDecoration(
              color: AppColors.card.withOpacity(0.88),
              borderRadius: BorderRadius.circular(36),
              border: Border.all(color: AppColors.glassBorder, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavIcon(Icons.explore_outlined, Icons.explore_rounded, 0, currentIndex, onTap),
                _NavIcon(Icons.forum_outlined, Icons.forum_rounded, 1, currentIndex, onTap),
                _AiOrb(isActive: currentIndex == 2, onTap: () => onTap(2)),
                _NavIcon(Icons.assignment_outlined, Icons.assignment_rounded, 3, currentIndex, onTap),
                _NavIcon(Icons.person_outline_rounded, Icons.person_rounded, 4, currentIndex, onTap),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AiOrb extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;
  const _AiOrb({required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: isActive
                ? [AppColors.primary, const Color(0xFF7C3AED)]
                : [AppColors.primary.withOpacity(0.85), AppColors.primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(isActive ? 0.55 : 0.25),
              blurRadius: isActive ? 24 : 10,
              spreadRadius: isActive ? 3 : 0,
            ),
          ],
        ),
        child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final int index;
  final int current;
  final void Function(int) onTap;
  const _NavIcon(this.icon, this.activeIcon, this.index, this.current, this.onTap);

  bool get isActive => index == current;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? AppColors.primary : AppColors.textSecondary,
              size: 24,
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.only(top: 5),
              height: 3,
              width: isActive ? 18 : 0,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
                boxShadow: isActive
                    ? [BoxShadow(color: AppColors.primary.withOpacity(0.6), blurRadius: 6)]
                    : [],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
