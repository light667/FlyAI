import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/providers/locale_provider.dart';
import '../providers/auth_provider.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(authNotifierProvider.notifier).sendPasswordReset(_emailCtrl.text);
      if (mounted) setState(() => _emailSent = true);
    } catch (e) {
      if (mounted) {
        final strings = ref.read(stringsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(strings.genericError),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final isFr = ref.watch(localeProvider).languageCode == 'fr';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 40),
              if (!_emailSent) ...[
                Text(
                  isFr ? 'Réinitialiser le mot de passe ' : 'Reset Password ',
                  style: AppTextStyles.displayMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  isFr
                      ? 'Saisis ton adresse e-mail et nous t\'enverrons un lien de réinitialisation.'
                      : 'Enter your email and we\'ll send you a reset link.',
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: 40),
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
                const SizedBox(height: 32),
                PrimaryButton(
                  label: isFr ? 'Envoyer le lien' : 'Send Reset Link',
                  isLoading: _isLoading,
                  onPressed: _reset,
                ),
              ] else ...[
                const SizedBox(height: 60),
                Center(
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mark_email_read_outlined, color: AppColors.success, size: 48),
                  ),
                ),
                const SizedBox(height: 32),
                Center(
                  child: Text(
                    isFr ? 'E-mail envoyé !' : 'Email Sent!',
                    style: AppTextStyles.headlineLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    isFr
                        ? 'Vérifie ta boîte mail à\n${_emailCtrl.text}'
                        : 'Check your inbox at\n${_emailCtrl.text}',
                    style: AppTextStyles.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 40),
                PrimaryButton(
                  label: strings.backToSignIn,
                  onPressed: () => context.pop(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
