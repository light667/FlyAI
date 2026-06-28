import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_router.dart';
import '../providers/profile_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../../scholarships/providers/scholarship_provider.dart';
import '../../scholarships/models/scholarship_model.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileNotifierProvider);
    final statsAsync = ref.watch(dashboardStatsProvider);
    final likedAsync = ref.watch(likedScholarshipsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('My Profile 👤', style: AppTextStyles.headlineSmall),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(AppRoutes.settings),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_off_outlined, size: 56, color: AppColors.error),
              const SizedBox(height: 16),
              Text('Failed to load profile details.', style: AppTextStyles.bodyMedium),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go(AppRoutes.profileSetup),
                child: const Text('Create Profile'),
              ),
            ],
          ),
        ),
        data: (profile) {
          if (profile == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.school_rounded, size: 72, color: AppColors.glassBorder),
                    const SizedBox(height: 24),
                    Text('Profile not complete', style: AppTextStyles.headlineSmall),
                    const SizedBox(height: 8),
                    Text(
                      'Complete your profile to enable personalized scholarship compatibility matches!',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => context.go(AppRoutes.profileSetup),
                      child: const Text('Set up Profile', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Avatar + Name Card
                Center(
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primary, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              blurRadius: 16,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 54,
                          backgroundColor: AppColors.card,
                          backgroundImage: profile.photoUrl != null
                              ? CachedNetworkImageProvider(profile.photoUrl!)
                              : const AssetImage('assets/images/logo.png') as ImageProvider,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        profile.fullName,
                        style: AppTextStyles.headlineMedium.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            '${profile.country} • ${profile.nationality}',
                            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Edit Button
                OutlinedButton.icon(
                  onPressed: () => context.push(AppRoutes.profileSetup),
                  icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.white),
                  label: const Text('Edit Profile Details', style: TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    side: BorderSide(color: AppColors.glassBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 24),

                // Stats Grid
                _buildStatsGrid(context, statsAsync),
                const SizedBox(height: 32),

                // Academic Information Card
                _buildSectionTitle('Academic Details'),
                const SizedBox(height: 12),
                _buildInfoCard([
                  _buildDetailRow('Education Level', profile.educationLevel),
                  _buildDetailRow('University/School', profile.university),
                  _buildDetailRow('Field of Study', profile.fieldOfStudy),
                  _buildDetailRow('Current GPA', '${profile.gpa}'),
                ]),
                const SizedBox(height: 24),

                // Language Levels
                _buildSectionTitle('Languages'),
                const SizedBox(height: 12),
                _buildInfoCard([
                  _buildDetailRow('English Proficiency', profile.englishLevel),
                  _buildDetailRow('French Proficiency', profile.frenchLevel),
                ]),
                const SizedBox(height: 24),

                // Target Fields & Countries
                _buildSectionTitle('Interests & Goals'),
                const SizedBox(height: 12),
                _buildInfoCard([
                  _buildTagRow('Target Countries', profile.targetCountries),
                  Divider(color: AppColors.glassBorder, height: 16),
                  _buildTagRow('Target Fields', profile.targetFields),
                  Divider(color: AppColors.glassBorder, height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Academic & Career Goals', style: AppTextStyles.labelLarge),
                      const SizedBox(height: 6),
                      Text(
                        profile.academicGoals.isNotEmpty ? profile.academicGoals : "None added yet.",
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary, height: 1.5),
                      ),
                    ],
                  ),
                ]),
                const SizedBox(height: 24),

                // Uploaded Documents
                _buildSectionTitle('Documents'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.file_present_rounded, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          profile.cvUrl != null ? 'Curriculum Vitae (CV) Uploaded' : 'No CV Uploaded',
                          style: AppTextStyles.bodyMedium,
                        ),
                      ),
                      if (profile.cvUrl != null)
                        const Icon(Icons.check_circle, color: AppColors.success, size: 20)
                      else
                        TextButton(
                          onPressed: () => context.push(AppRoutes.profileSetup),
                          child: const Text('Upload'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Saved Scholarships
                _buildSectionTitle('Saved Scholarships'),
                const SizedBox(height: 12),
                _buildSavedScholarshipsList(context, likedAsync),
                const SizedBox(height: 48),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagRow(String label, List<String> tags) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelLarge),
        const SizedBox(height: 10),
        tags.isEmpty
            ? Text('None added yet.', style: AppTextStyles.bodySmall)
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tags.map((t) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Text(t, style: AppTextStyles.bodySmall.copyWith(color: Colors.white)),
                  );
                }).toList(),
              ),
      ],
    );
  }

  Widget _buildStatsGrid(BuildContext context, AsyncValue<DashboardStats> statsAsync) {
    return statsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (stats) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.4,
        children: [
          _StatCard(
            label: 'Total Matches',
            value: '${stats.totalMatches}',
            icon: Icons.favorite_rounded,
            color: AppColors.success,
          ),
          _StatCard(
            label: 'Saved',
            value: '${stats.savedScholarships}',
            icon: Icons.bookmark_rounded,
            color: AppColors.primary,
          ),
          _StatCard(
            label: 'Active',
            value: '${stats.activeApplications}',
            icon: Icons.assignment_rounded,
            color: AppColors.secondary,
          ),
          _StatCard(
            label: 'Avg. Match',
            value: '${stats.avgCompatibility.round()}%',
            icon: Icons.bolt_rounded,
            color: AppColors.warning,
          ),
        ],
      ),
    );
  }

  Widget _buildSavedScholarshipsList(BuildContext context, AsyncValue<List<ScholarshipModel>> likedAsync) {
    return likedAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (scholarships) {
        if (scholarships.isEmpty) {
          return _buildInfoCard([
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No saved scholarships yet.',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ),
          ]);
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: scholarships.length,
          itemBuilder: (context, index) {
            return _ScholarshipListTile(scholarship: scholarships[index]);
          },
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.08),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: AppTextStyles.headlineLarge.copyWith(color: color)),
              Text(label, style: AppTextStyles.caption),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScholarshipListTile extends StatelessWidget {
  final ScholarshipModel scholarship;
  const _ScholarshipListTile({required this.scholarship});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AppColors.primary.withOpacity(0.1),
            ),
            child: scholarship.imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: scholarship.imageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const Icon(
                          Icons.school_rounded, color: AppColors.primary),
                    ),
                  )
                : const Icon(Icons.school_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(scholarship.title,
                    style: AppTextStyles.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(
                  '${scholarship.country} · ${scholarship.fundingType}',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Text(
              '${scholarship.compatibilityScore}%',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
