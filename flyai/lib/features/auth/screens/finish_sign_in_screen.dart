import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:universal_html/html.dart' as html;
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../providers/auth_provider.dart';

class FinishSignInScreen extends ConsumerStatefulWidget {
  const FinishSignInScreen({super.key});

  @override
  ConsumerState<FinishSignInScreen> createState() => _FinishSignInScreenState();
}

class _FinishSignInScreenState extends ConsumerState<FinishSignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _isVerifying = true;
  bool _needEmail = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processSignInLink();
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _processSignInLink() async {
    // 1. Get the current URL
    String currentUrl = '';
    if (kIsWeb) {
      currentUrl = html.window.location.href;
    } else {
      // On mobile, the deep link matches GoRouterState.of(context).uri.toString()
      currentUrl = GoRouterState.of(context).uri.toString();
    }

    if (!AuthService.isSignInWithEmailLink(currentUrl)) {
      setState(() {
        _isVerifying = false;
        _errorMessage = ref.read(stringsProvider).linkExpired;
      });
      return;
    }

    // 2. Check if we have a saved email
    final savedEmail = await AuthService.getSavedEmailForSignIn();
    if (savedEmail != null && savedEmail.isNotEmpty) {
      _completeSignIn(savedEmail, currentUrl);
    } else {
      setState(() {
        _isVerifying = false;
        _needEmail = true;
      });
    }
  }

  Future<void> _completeSignIn(String email, String emailLink) async {
    setState(() {
      _isVerifying = true;
      _needEmail = false;
      _errorMessage = null;
    });

    try {
      await ref.read(authNotifierProvider.notifier).completeSignInWithLink(
            email: email,
            emailLink: emailLink,
          );

      // Verify profile and redirect
      if (mounted) {
        final exists = await ref.read(profileExistsProvider.future);
        if (mounted) {
          if (exists) {
            context.go(AppRoutes.home);
          } else {
            context.go(AppRoutes.profileSetup);
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isVerifying = false;
        _errorMessage = AuthService.mapFirebaseError(
          e,
          fr: ref.read(localeProvider).languageCode == 'fr',
        );
      });
    } catch (e) {
      setState(() {
        _isVerifying = false;
        _errorMessage = ref.read(stringsProvider).genericError;
      });
    }
  }

  void _submitEmail() {
    if (!_formKey.currentState!.validate()) return;
    String currentUrl = '';
    if (kIsWeb) {
      currentUrl = html.window.location.href;
    } else {
      currentUrl = GoRouterState.of(context).uri.toString();
    }
    _completeSignIn(_emailCtrl.text.trim(), currentUrl);
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E1B4B),
              Color(0xFF0F172A),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Card(
                elevation: 0,
                color: Colors.white.withOpacity(0.03),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(
                    color: Colors.white.withOpacity(0.08),
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header Symbol
                      Image.asset(
                        'assets/images/symbol.png',
                        height: 64,
                      ),
                      const SizedBox(height: 32),

                      if (_isVerifying) ...[
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          strings.verifyingLink,
                          style: AppTextStyles.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ] else if (_errorMessage != null) ...[
                        Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.error,
                          size: 56,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        PrimaryButton(
                          label: strings.backToSignIn,
                          onPressed: () => context.go(AppRoutes.login),
                        ),
                      ] else if (_needEmail) ...[
                        Text(
                          strings.enterEmailAgain,
                          style: AppTextStyles.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        Form(
                          key: _formKey,
                          child: AppTextField(
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
                        ),
                        const SizedBox(height: 24),
                        PrimaryButton(
                          label: strings.confirm,
                          onPressed: _submitEmail,
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => context.go(AppRoutes.login),
                          child: Text(
                            strings.backToSignIn,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
