import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../providers/auth_provider.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
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
      await ref
          .read(authNotifierProvider.notifier)
          .sendPasswordReset(_emailCtrl.text);
      if (mounted) setState(() => _emailSent = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.genericError),
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
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: AppColors.textPrimary),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 40),
              if (!_emailSent) ...[
                Text('Reset Password 🔑', style: AppTextStyles.displayMedium),
                const SizedBox(height: 8),
                Text(
                  'Enter your email and we\'ll send you a reset link.',
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: 40),
                Form(
                  key: _formKey,
                  child: AppTextField(
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
                ),
                const SizedBox(height: 32),
                PrimaryButton(
                  label: AppStrings.resetPassword,
                  isLoading: _isLoading,
                  onPressed: _reset,
                ),
              ] else ...[
                // Success state
                const SizedBox(height: 60),
                Center(
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mark_email_read_outlined,
                      color: AppColors.success,
                      size: 48,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Center(
                  child: Text('Email Sent! ✉️',
                      style: AppTextStyles.headlineLarge,
                      textAlign: TextAlign.center),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'Check your inbox at\n${_emailCtrl.text}',
                    style: AppTextStyles.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 40),
                PrimaryButton(
                  label: 'Back to Sign In',
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
