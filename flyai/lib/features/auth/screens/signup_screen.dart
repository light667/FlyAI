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

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(authNotifierProvider.notifier).signUpWithEmail(
            email: _emailCtrl.text,
            password: _passwordCtrl.text,
            fullName: _nameCtrl.text,
          );
      if (mounted) context.go(AppRoutes.profileSetup);
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
      if (mounted) {
        final exists = await ref.read(profileExistsProvider.future);
        if (!mounted) return;
        context.go(exists ? AppRoutes.home : AppRoutes.profileSetup);
      }
    } catch (e) {
      _showError(AppStrings.genericError);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
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
                // Back button
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: AppColors.textPrimary),
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(height: 24),
                Text('Create Account ✨', style: AppTextStyles.displayMedium),
                const SizedBox(height: 8),
                Text(
                  'Start your scholarship journey today',
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: 40),

                // Full Name
                AppTextField(
                  controller: _nameCtrl,
                  label: AppStrings.fullNameLabel,
                  hint: 'Your full name',
                  prefixIcon: Icons.person_outline,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? AppStrings.fieldRequired : null,
                ),
                const SizedBox(height: 16),

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
                const SizedBox(height: 16),

                // Confirm Password
                AppTextField(
                  controller: _confirmCtrl,
                  label: AppStrings.confirmPasswordLabel,
                  hint: '••••••••',
                  obscureText: _obscureConfirm,
                  prefixIcon: Icons.lock_outline,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return AppStrings.fieldRequired;
                    if (v != _passwordCtrl.text) {
                      return AppStrings.passwordsDoNotMatch;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                PrimaryButton(
                  label: AppStrings.signUp,
                  isLoading: _isLoading,
                  onPressed: _signUp,
                ),
                const SizedBox(height: 24),

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

                SocialButton(
                  label: AppStrings.continueWithGoogle,
                  iconPath: 'assets/images/google.jpg',
                  onPressed: _isLoading ? null : _googleSignIn,
                ),
                const SizedBox(height: 40),

                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(AppStrings.alreadyHaveAccount,
                          style: AppTextStyles.bodyMedium),
                      TextButton(
                        onPressed: () => context.pop(),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          AppStrings.signIn,
                          style: AppTextStyles.labelLarge
                              .copyWith(color: AppColors.primary),
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
