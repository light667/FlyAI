import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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
  bool _obscure = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkRedirectResult();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkRedirectResult() async {
    if (!kIsWeb) return;
    setState(() => _isLoading = true);
    try {
      final cred = await AuthService.getRedirectResult();
      if (cred != null && mounted) await _navigate();
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(authNotifierProvider.notifier).signInWithEmail(
            email: _emailCtrl.text,
            password: _passwordCtrl.text,
          );
      if (mounted) await _navigate();
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
      if (mounted && FirebaseAuth.instance.currentUser != null) await _navigate();
    } catch (_) {
      _showError(ref.read(stringsProvider).genericError);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _navigate() async {
    final exists = await ref.read(profileExistsProvider.future);
    if (!mounted) return;
    context.go(exists ? AppRoutes.home : AppRoutes.profileSetup);
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
    final locale = ref.watch(localeProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                // ── Gradient header ──────────────────────────────────────
                Container(
                  height: 260,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0A0F1C), Color(0xFF1E1B4B), Color(0xFF0A0F1C)],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Glow
                      Positioned(
                        top: -40,
                        right: -40,
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [AppColors.primary.withOpacity(0.3), Colors.transparent],
                            ),
                          ),
                        ),
                      ),
                      // Logo + title
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 60),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [AppColors.primary, Color(0xFF7C3AED)],
                                  ),
                                ),
                                child: ClipOval(
                                  child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'FLY AI',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 3,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          Text(
                            strings.welcomeBack,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            strings.welcomeBackSub,
                            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
                          ),
                        ],
                      ),
                      // Language pill
                      Positioned(
                        top: 52,
                        right: 20,
                        child: PopupMenuButton<Locale>(
                          initialValue: locale,
                          onSelected: (l) => ref.read(localeProvider.notifier).setLocale(l),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(50),
                              border: Border.all(color: Colors.white.withOpacity(0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.language_rounded, size: 14, color: Colors.white70),
                                const SizedBox(width: 4),
                                Text(locale.languageCode.toUpperCase(),
                                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          itemBuilder: (_) => [
                            PopupMenuItem(value: const Locale('fr'), child: Text(strings.french)),
                            PopupMenuItem(value: const Locale('en'), child: Text(strings.english)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Form ────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                          controller: _passwordCtrl,
                          label: strings.passwordLabel,
                          hint: '••••••••',
                          obscureText: _obscure,
                          prefixIcon: Icons.lock_outline,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              color: AppColors.textSecondary,
                            ),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return strings.fieldRequired;
                            if (v.length < 6) return strings.passwordTooShort;
                            return null;
                          },
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => context.push(AppRoutes.forgotPassword),
                            child: Text(strings.forgotPassword,
                                style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        PrimaryButton(label: strings.signIn, isLoading: _isLoading, onPressed: _signIn),
                        const SizedBox(height: 28),
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
                                child: Text(strings.signUp,
                                    style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary)),
                              ),
                            ],
                          ),
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
