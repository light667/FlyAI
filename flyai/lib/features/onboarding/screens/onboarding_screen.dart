import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/primary_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _controller = PageController();
  int _page = 0;
  late AnimationController _fadeCtrl;
  late Animation<double> _fade;

  static const _slides = [
    _Slide(
      title: 'Find Your\nScholarship',
      subtitle: 'Discover hundreds of global scholarships matched to your profile and ambitions.',
      icon: Icons.explore_rounded,
      gradient: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
      accentGradient: [Color(0xFF60A5FA), Color(0xFF2563EB)],
    ),
    _Slide(
      title: 'AI Finds\nYour Match',
      subtitle: 'Swipe through opportunities. Our AI calculates your compatibility score in real time.',
      icon: Icons.auto_awesome_rounded,
      gradient: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
      accentGradient: [Color(0xFFA78BFA), Color(0xFF7C3AED)],
    ),
    _Slide(
      title: 'Apply with\nConfidence',
      subtitle: 'Get AI-assisted CV reviews, motivation letters, and interview prep — all in one place.',
      icon: Icons.rocket_launch_rounded,
      gradient: [Color(0xFF0891B2), Color(0xFF0E7490)],
      accentGradient: [Color(0xFF22D3EE), Color(0xFF0891B2)],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _slides.length - 1) {
      _fadeCtrl.reverse().then((_) {
        _controller.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
        _fadeCtrl.forward();
      });
    } else {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_page];
    final isLast = _page == _slides.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1C),
      body: Stack(
        children: [
          // Animated gradient background
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.4, -0.6),
                radius: 1.4,
                colors: [
                  slide.gradient[0].withOpacity(0.35),
                  const Color(0xFF0A0F1C),
                ],
              ),
            ),
          ),

          // Bottom glow
          Positioned(
            bottom: -80,
            left: 0,
            right: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              height: 300,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.0,
                  colors: [
                    slide.gradient[0].withOpacity(0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                // Skip
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: () => context.go(AppRoutes.login),
                    child: Text(
                      'Skip',
                      style: AppTextStyles.labelLarge.copyWith(color: Colors.white54),
                    ),
                  ),
                ),

                // PageView
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    onPageChanged: (i) {
                      _fadeCtrl.reverse().then((_) {
                        setState(() => _page = i);
                        _fadeCtrl.forward();
                      });
                    },
                    itemCount: _slides.length,
                    itemBuilder: (_, i) => _OnboardSlide(slide: _slides[i], fade: _fade),
                  ),
                ),

                // Bottom controls
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 48),
                  child: Column(
                    children: [
                      // Dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_slides.length, (i) {
                          final active = i == _page;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: active ? 28 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: active ? slide.gradient[0] : Colors.white24,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 28),

                      // CTA button
                      GestureDetector(
                        onTap: _next,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: slide.gradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: slide.gradient[0].withOpacity(0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  isLast ? 'Get Started' : 'Next',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  isLast ? Icons.rocket_launch_rounded : Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
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

class _Slide {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final List<Color> accentGradient;
  const _Slide({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.accentGradient,
  });
}

class _OnboardSlide extends StatelessWidget {
  final _Slide slide;
  final Animation<double> fade;
  const _OnboardSlide({required this.slide, required this.fade});

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: fade,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon orb
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: slide.gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: slide.gradient[0].withOpacity(0.5),
                    blurRadius: 50,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: Icon(slide.icon, size: 60, color: Colors.white),
            ),
            const SizedBox(height: 52),

            Text(
              slide.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 38,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              slide.subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 16,
                height: 1.65,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
