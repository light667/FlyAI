import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/social_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(authNotifierProvider.notifier).signInWithEmail(
            email: _emailCtrl.text,
            password: _passwordCtrl.text,
          );
      if (mounted) await _navigateAfterAuth();
    } on FirebaseAuthException catch (e) {
      _showError(AuthService.mapFirebaseError(e));
    } catch (e) {
      _showError(AppStrings.genericError);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authNotifierProvider.notifier).signInWithGoogle();
      if (mounted) await _navigateAfterAuth();
    } catch (e) {
      _showError(AppStrings.genericError);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _appleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authNotifierProvider.notifier).signInWithApple();
      if (mounted) await _navigateAfterAuth();
    } catch (e) {
      _showError(AppStrings.genericError);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateAfterAuth() async {
    final exists = await ref.read(profileExistsProvider.future);
    if (!mounted) return;
    if (exists) {
      context.go(AppRoutes.home);
    } else {
      context.go(AppRoutes.profileSetup);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                // Logo + Title
                Center(
                  child: Image.asset(
                    'assets/images/symbol.png',
                    height: 56,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Welcome back 👋',
                  style: AppTextStyles.displayMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to continue your journey',
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: 40),

                // Email
                AppTextField(
                  controller: _emailCtrl,
                  label: AppStrings.emailLabel,
                  hint: 'you@example.com',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.email_outlined,
                  validator: (v) {
                    if (v == null || v.isEmpty) return AppStrings.fieldRequired;
                    if (!v.contains('@')) return AppStrings.invalidEmail;
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password
                AppTextField(
                  controller: _passwordCtrl,
                  label: AppStrings.passwordLabel,
                  hint: '••••••••',
                  obscureText: _obscurePassword,
                  prefixIcon: Icons.lock_outline,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return AppStrings.fieldRequired;
                    if (v.length < 6) return AppStrings.passwordTooShort;
                    return null;
                  },
                ),
                const SizedBox(height: 8),

                // Forgot Password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push(AppRoutes.forgotPassword),
                    child: Text(AppStrings.forgotPassword),
                  ),
                ),
                const SizedBox(height: 24),

                // Sign In Button
                PrimaryButton(
                  label: AppStrings.signIn,
                  isLoading: _isLoading,
                  onPressed: _signIn,
                ),
                const SizedBox(height: 24),

                // Divider
                Row(
                  children: [
                    const Expanded(child: Divider(color: AppColors.glassBorder)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('or', style: AppTextStyles.bodySmall),
                    ),
                    const Expanded(child: Divider(color: AppColors.glassBorder)),
                  ],
                ),
                const SizedBox(height: 24),

                // Social Buttons
                SocialButton(
                  label: AppStrings.continueWithGoogle,
                  iconPath: 'assets/images/google.jpg',
                  onPressed: _isLoading ? null : _googleSignIn,
                ),
                const SizedBox(height: 12),
                SocialButton(
                  label: AppStrings.continueWithApple,
                  iconPath: 'assets/images/apple.png',
                  onPressed: _isLoading ? null : _appleSignIn,
                ),
                const SizedBox(height: 40),

                // Sign Up Link
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        AppStrings.dontHaveAccount,
                        style: AppTextStyles.bodyMedium,
                      ),
                      TextButton(
                        onPressed: () => context.push(AppRoutes.signup),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          AppStrings.signUp,
                          style: AppTextStyles.labelLarge.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
