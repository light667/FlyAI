import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/social_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/providers/locale_provider.dart';
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
      _showError(AuthService.mapFirebaseError(
        e,
        fr: ref.read(localeProvider).languageCode == 'fr',
      ));
    } catch (e) {
      _showError(ref.read(stringsProvider).genericError);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authNotifierProvider.notifier).signInWithGoogle();
      if (mounted && FirebaseAuth.instance.currentUser != null) {
        await _navigateAfterAuth();
      }
    } catch (e) {
      _showError(ref.read(stringsProvider).genericError);
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
      _showError(ref.read(stringsProvider).genericError);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateAfterAuth() async {
    final exists = await ref.read(profileExistsProvider.future);
    if (!mounted) return;
    context.go(exists ? AppRoutes.home : AppRoutes.profileSetup);
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
    final strings = ref.watch(stringsProvider);
    final currentLocale = ref.watch(localeProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Language Selector
                Align(
                  alignment: Alignment.topRight,
                  child: PopupMenuButton<Locale>(
                    initialValue: currentLocale,
                    icon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.language_rounded, size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          currentLocale.languageCode.toUpperCase(),
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                        ),
                        Icon(Icons.arrow_drop_down_rounded, color: AppColors.textSecondary),
                      ],
                    ),
                    onSelected: (locale) => ref.read(localeProvider.notifier).setLocale(locale),
                    itemBuilder: (context) => [
                      PopupMenuItem(value: const Locale('fr'), child: Text(strings.french)),
                      PopupMenuItem(value: const Locale('en'), child: Text(strings.english)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Logo
                Center(child: Image.asset('assets/images/symbol.png', height: 56)),
                const SizedBox(height: 32),

                Text(strings.welcomeBack, style: AppTextStyles.displayMedium),
                const SizedBox(height: 8),
                Text(strings.welcomeBackSub, style: AppTextStyles.bodyMedium),
                const SizedBox(height: 40),

                // Email
                AppTextField(
                  controller: _emailCtrl,
                  label: strings.emailLabel,
                  hint: strings.emailHint,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.email_outlined,
                  validator: (v) {
                    if (v == null || v.isEmpty) return strings.fieldRequired;
                    if (!v.contains('@')) return strings.invalidEmail;
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password
                AppTextField(
                  controller: _passwordCtrl,
                  label: strings.passwordLabel,
                  hint: '••••••••',
                  obscureText: _obscurePassword,
                  prefixIcon: Icons.lock_outline,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return strings.fieldRequired;
                    if (v.length < 6) return strings.passwordTooShort;
                    return null;
                  },
                ),
                const SizedBox(height: 8),

                // Forgot Password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push(AppRoutes.forgotPassword),
                    child: Text(
                      strings.forgotPassword,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Sign In Button
                PrimaryButton(
                  label: strings.signIn,
                  isLoading: _isLoading,
                  onPressed: _signIn,
                ),
                const SizedBox(height: 32),

                // Divider
                Row(
                  children: [
                    Expanded(child: Divider(color: AppColors.glassBorder)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(strings.orContinueWith, style: AppTextStyles.bodySmall),
                    ),
                    Expanded(child: Divider(color: AppColors.glassBorder)),
                  ],
                ),
                const SizedBox(height: 24),

                // Social Buttons
                SocialButton(
                  label: strings.continueWithGoogle,
                  iconPath: 'assets/images/google.jpg',
                  onPressed: _isLoading ? null : _googleSignIn,
                ),
                const SizedBox(height: 12),
                SocialButton(
                  label: strings.continueWithApple,
                  iconPath: 'assets/images/apple.png',
                  onPressed: _isLoading ? null : _appleSignIn,
                ),
                const SizedBox(height: 40),

                // Sign Up Link
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(strings.dontHaveAccount, style: AppTextStyles.bodyMedium),
                      TextButton(
                        onPressed: () => context.push(AppRoutes.signup),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          strings.signUp,
                          style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary),
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
