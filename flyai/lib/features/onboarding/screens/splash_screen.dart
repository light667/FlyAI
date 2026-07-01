import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 2800));
    if (!mounted) return;

    final user = AuthService.currentUser;
    if (user == null) {
      context.go(AppRoutes.onboarding);
      return;
    }

    // Check if profile exists
    final profile = await SupabaseService.fetchOne(
      'profiles',
      'firebase_uid',
      user.uid,
    );

    if (!mounted) return;
    if (profile != null) {
      context.go(AppRoutes.home);
    } else {
      context.go(AppRoutes.profileSetup);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.25),
                    blurRadius: 24,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 32),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
              ).createShader(bounds),
              child: const Text(
                'Fly AI',
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Swipe. Match. Apply. Fly.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
