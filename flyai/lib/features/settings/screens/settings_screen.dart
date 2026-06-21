import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_router.dart';
import '../../../core/providers/locale_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _pushNotifications = true;
  bool _emailUpdates = true;
  bool _anonymousAnalytics = false;

  Future<void> _logout() async {
    final strings = ref.read(stringsProvider);
    try {
      await ref.read(authNotifierProvider.notifier).signOut();
      if (mounted) {
        context.go(AppRoutes.login);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${strings.genericError}: $e"),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final currentLocale = ref.watch(localeProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(strings.settings, style: AppTextStyles.headlineSmall),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Section 1: Account Settings
          _buildSectionHeader(strings.account),
          _buildSettingsCard([
            _buildSettingsTile(
              icon: Icons.person_outline_rounded,
              title: strings.editProfile,
              subtitle: strings.editProfileSub,
              onTap: () => context.push(AppRoutes.profileSetup),
            ),
            Divider(color: AppColors.glassBorder, height: 1),
            _buildSettingsTile(
              icon: Icons.translate_rounded,
              title: strings.appLanguage,
              subtitle: currentLocale.languageCode == 'fr'
                  ? strings.french
                  : strings.english,
              onTap: () {
                ref.read(localeProvider.notifier).toggleLocale();
              },
            ),
            Divider(color: AppColors.glassBorder, height: 1),
            _buildSwitchTile(
              icon: Icons.dark_mode_outlined,
              title: currentLocale.languageCode == 'fr' ? 'Thème Sombre' : 'Dark Theme',
              value: ref.watch(themeModeProvider) == ThemeMode.dark,
              onChanged: (val) {
                ref.read(themeModeProvider.notifier).toggleTheme();
              },
            ),
          ]),
          const SizedBox(height: 24),

          // Section 2: Notifications Settings
          _buildSectionHeader(strings.notifications),
          _buildSettingsCard([
            _buildSwitchTile(
              icon: Icons.notifications_none_rounded,
              title: strings.pushNotifications,
              value: _pushNotifications,
              onChanged: (val) => setState(() => _pushNotifications = val),
            ),
            Divider(color: AppColors.glassBorder, height: 1),
            _buildSwitchTile(
              icon: Icons.mail_outline_rounded,
              title: strings.emailUpdates,
              value: _emailUpdates,
              onChanged: (val) => setState(() => _emailUpdates = val),
            ),
          ]),
          const SizedBox(height: 24),

          // Section 3: Privacy and Terms Settings
          _buildSectionHeader(strings.privacyAndData),
          _buildSettingsCard([
            _buildSwitchTile(
              icon: Icons.analytics_outlined,
              title: strings.anonymousAnalytics,
              value: _anonymousAnalytics,
              onChanged: (val) => setState(() => _anonymousAnalytics = val),
            ),
            Divider(color: AppColors.glassBorder, height: 1),
            _buildSettingsTile(
              icon: Icons.security_outlined,
              title: strings.privacyPolicy,
              onTap: () {
                _showInfoDialog(context, strings.privacyPolicy, strings.privacyPolicyContent);
              },
            ),
            Divider(color: AppColors.glassBorder, height: 1),
            _buildSettingsTile(
              icon: Icons.description_outlined,
              title: strings.termsOfService,
              onTap: () {
                _showInfoDialog(context, strings.termsOfService, strings.termsOfServiceContent);
              },
            ),
          ]),
          const SizedBox(height: 32),

          // Section 4: Log Out Button
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 24),
            child: OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded, color: AppColors.error),
              label: Text(strings.logOut, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: AppColors.error, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),

          // About footer version
          Center(
            child: Text(
              'Fly AI v1.0.0 (Beta)',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(title, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
      subtitle: subtitle != null ? Text(subtitle, style: AppTextStyles.bodySmall) : null,
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(icon, color: AppColors.textSecondary),
      title: Text(title, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
      value: value,
      activeColor: AppColors.primary,
      onChanged: onChanged,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  void _showInfoDialog(BuildContext context, String title, String content) {
    final strings = ref.read(stringsProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(title),
        content: Text(content, style: TextStyle(color: AppColors.textSecondary, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(strings.close, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
