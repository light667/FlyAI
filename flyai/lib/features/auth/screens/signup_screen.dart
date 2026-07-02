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

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});
  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(authNotifierProvider.notifier).signUpWithEmail(
            email: _emailCtrl.text,
            password: _passCtrl.text,
            fullName: _nameCtrl.text,
          );
      if (mounted) context.go(AppRoutes.profileSetup);
    } on FirebaseAuthException catch (e) {
      _showError(AuthService.mapFirebaseError(e, fr: ref.read(localeProvider).languageCode == 'fr'));
    } catch (_) {
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
        final exists = await ref.read(profileExistsProvider.future);
        if (mounted) context.go(exists ? AppRoutes.home : AppRoutes.profileSetup);
      }
    } catch (_) {
      _showError(ref.read(stringsProvider).genericError);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                // ── Header ──────────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0A0F1C), Color(0xFF1E1B4B), Color(0xFF0A0F1C)],
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 0,
                        left: -60,
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [const Color(0xFF7C3AED).withOpacity(0.25), Colors.transparent],
                            ),
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () => context.pop(),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            strings.createAccount,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            strings.createAccountSub,
                            style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Form ────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        AppTextField(
                          controller: _nameCtrl,
                          label: strings.fullNameLabel,
                          hint: strings.fullNameLabel,
                          prefixIcon: Icons.person_outline,
                          validator: (v) => (v == null || v.isEmpty) ? strings.fieldRequired : null,
                        ),
                        const SizedBox(height: 14),
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
                        const SizedBox(height: 14),
                        AppTextField(
                          controller: _passCtrl,
                          label: strings.passwordLabel,
                          hint: '••••••••',
                          obscureText: _obscurePass,
                          prefixIcon: Icons.lock_outline,
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                color: AppColors.textSecondary),
                            onPressed: () => setState(() => _obscurePass = !_obscurePass),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return strings.fieldRequired;
                            if (v.length < 6) return strings.passwordTooShort;
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          controller: _confirmCtrl,
                          label: strings.confirmPasswordLabel,
                          hint: '••••••••',
                          obscureText: _obscureConfirm,
                          prefixIcon: Icons.lock_outline,
                          suffixIcon: IconButton(
                            icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                color: AppColors.textSecondary),
                            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return strings.fieldRequired;
                            if (v != _passCtrl.text) return strings.passwordsDoNotMatch;
                            return null;
                          },
                        ),
                        const SizedBox(height: 28),
                        PrimaryButton(label: strings.signUp, isLoading: _isLoading, onPressed: _signUp),
                        const SizedBox(height: 24),
                        Row(children: [
                          Expanded(child: Divider(color: AppColors.glassBorder)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(strings.orContinueWith, style: AppTextStyles.bodySmall),
                          ),
                          Expanded(child: Divider(color: AppColors.glassBorder)),
                        ]),
                        const SizedBox(height: 20),
                        SocialButton(
                          label: strings.continueWithGoogle,
                          iconPath: 'assets/images/google.jpg',
                          onPressed: _isLoading ? null : _googleSignIn,
                        ),
                        const SizedBox(height: 36),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(strings.alreadyHaveAccount, style: AppTextStyles.bodyMedium),
                            TextButton(
                              onPressed: () => context.pop(),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(strings.signIn,
                                  style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
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
