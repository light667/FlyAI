import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../profile/models/profile_model.dart';
import 'direct_chat_screen.dart';

class MemberProfileScreen extends StatelessWidget {
  final ProfileModel profile;

  const MemberProfileScreen({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final name = profile.fullName.trim().isNotEmpty ? profile.fullName : 'Scholar';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'S';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.background,
            foregroundColor: AppColors.textPrimary,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Background gradient
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [const Color(0xFF1E293B), AppColors.background],
                      ),
                    ),
                  ),
                  // Decorative blobs
                  Positioned(
                    top: -40,
                    right: -40,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  // Avatar
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                  colors: [AppColors.primary, Color(0xFF7C3AED)]),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.4),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: profile.photoUrl != null &&
                                    profile.photoUrl!.isNotEmpty
                                ? ClipOval(
                                    child: Image.network(profile.photoUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            _Initial(initial: initial, size: 32)))
                                : _Initial(initial: initial, size: 32),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Profile content ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + message button
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: AppTextStyles.displayMedium
                                    .copyWith(fontWeight: FontWeight.w800)),
                            if (profile.fieldOfStudy.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(profile.fieldOfStudy,
                                  style: AppTextStyles.titleMedium.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DirectChatScreen(
                                peerId: profile.firebaseUid,
                                peerProfile: profile),
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [AppColors.primary, Color(0xFF7C3AED)]),
                            borderRadius: BorderRadius.circular(50),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chat_bubble_rounded,
                                  color: Colors.white, size: 16),
                              SizedBox(width: 8),
                              Text('Message',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Info cards
                  _InfoSection(
                    title: 'Informations académiques',
                    children: [
                      if (profile.university.isNotEmpty)
                        _InfoRow(Icons.school_outlined, 'Université', profile.university),
                      if (profile.educationLevel.isNotEmpty)
                        _InfoRow(Icons.grade_outlined, "Niveau d'études", profile.educationLevel),
                      if (profile.gpa > 0)
                        _InfoRow(Icons.star_outline_rounded, 'GPA / Moyenne', profile.gpa.toString()),
                    ],
                  ),

                  if (profile.nationality.isNotEmpty || profile.country.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _InfoSection(
                      title: 'Localisation',
                      children: [
                        if (profile.nationality.isNotEmpty)
                          _InfoRow(Icons.flag_outlined, 'Nationalité', profile.nationality),
                        if (profile.country.isNotEmpty)
                          _InfoRow(Icons.location_on_outlined, 'Pays de résidence', profile.country),
                      ],
                    ),
                  ],

                  if (profile.targetFields.isNotEmpty ||
                      profile.targetCountries.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _InfoSection(
                      title: 'Objectifs',
                      children: [
                        if (profile.targetFields.isNotEmpty)
                          _InfoRow(Icons.explore_outlined, 'Domaines visés',
                              profile.targetFields.take(3).join(', ')),
                        if (profile.targetCountries.isNotEmpty)
                          _InfoRow(Icons.travel_explore_rounded, 'Pays cibles',
                              profile.targetCountries.take(3).join(', ')),
                      ],
                    ),
                  ],

                  if (profile.englishLevel.isNotEmpty || profile.frenchLevel.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _InfoSection(
                      title: 'Langues',
                      children: [
                        if (profile.englishLevel.isNotEmpty)
                          _InfoRow(Icons.language_rounded, 'Anglais', profile.englishLevel),
                        if (profile.frenchLevel.isNotEmpty)
                          _InfoRow(Icons.translate_rounded, 'Français', profile.frenchLevel),
                      ],
                    ),
                  ],

                  if (profile.academicGoals.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _InfoSection(
                      title: 'Objectifs académiques',
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(profile.academicGoals,
                              style: AppTextStyles.bodyMedium.copyWith(
                                  height: 1.6, color: AppColors.textPrimary)),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Initial extends StatelessWidget {
  final String initial;
  final double size;
  const _Initial({required this.initial, required this.size});
  @override
  Widget build(BuildContext context) => Center(
        child: Text(initial,
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: size)),
      );
}

class _InfoSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _InfoSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text(value,
                  style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
            ],
          ),
        ],
      ),
    );
  }
}
