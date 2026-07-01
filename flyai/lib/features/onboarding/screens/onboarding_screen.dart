import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/primary_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  static const _pages = [
    _OnboardingData(
      title: AppStrings.onboarding1Title,
      description: AppStrings.onboarding1Desc,
      icon: Icons.school_rounded,
    ),
    _OnboardingData(
      title: AppStrings.onboarding2Title,
      description: AppStrings.onboarding2Desc,
      icon: Icons.auto_awesome_rounded,
    ),
    _OnboardingData(
      title: AppStrings.onboarding3Title,
      description: AppStrings.onboarding3Desc,
      icon: Icons.rocket_launch_rounded,
    ),
  ];

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      context.go(AppRoutes.login);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Content Slides
          PageView.builder(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemCount: _pages.length,
            itemBuilder: (context, i) {
              return _OnboardingSlide(data: _pages[i]);
            },
          ),

          // Top bar: Only Skip button on the right
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => context.go(AppRoutes.login),
                    child: Text(
                      AppStrings.skip,
                      style: AppTextStyles.labelLarge.copyWith(
                        color: const Color(0xFF64748B), // Slate 500
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Page Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: _currentPage == i ? 28 : 8,
                        decoration: BoxDecoration(
                          color: _currentPage == i
                              ? AppColors.primary
                              : const Color(0xFFE2E8F0), // Slate 200
                          borderRadius: BorderRadius.circular(50),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  PrimaryButton(
                    label: isLast ? AppStrings.getStarted : AppStrings.next,
                    onPressed: _next,
                    icon: isLast ? Icons.rocket_launch_rounded : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingData {
  final String title;
  final String description;
  final IconData icon;

  const _OnboardingData({
    required this.title,
    required this.description,
    required this.icon,
  });
}

class _OnboardingSlide extends StatelessWidget {
  final _OnboardingData data;

  const _OnboardingSlide({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Styled Icon Container
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.12),
                  AppColors.secondary.withOpacity(0.06),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  data.icon,
                  size: 48,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 48),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: AppTextStyles.displayMedium.copyWith(
              color: const Color(0xFF0F172A), // Slate 900
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: const Color(0xFF64748B), // Slate 500
              height: 1.6,
            ),
          ),
          const SizedBox(height: 120), // Spacer to avoid overlapping bottom buttons
        ],
      ),
    );
  }
}
