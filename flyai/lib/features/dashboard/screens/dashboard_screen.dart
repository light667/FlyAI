import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/auth_service.dart';
import '../../scholarships/models/scholarship_model.dart';
import '../../scholarships/providers/scholarship_provider.dart';
import '../providers/dashboard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final likedAsync = ref.watch(likedScholarshipsProvider);
    final user = AuthService.currentUser;
    final displayName = user?.displayName ?? 'Scholar';

    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(dashboardStatsProvider);
          ref.invalidate(likedScholarshipsProvider);
        },
        child: CustomScrollView(
          slivers: [
            // ── Header ────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 60, 24, 28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Welcome back,', style: AppTextStyles.bodyMedium),
                              Text(
                                displayName.split(' ').first,
                                style: AppTextStyles.displayMedium,
                              ),
                            ],
                          ),
                        ),
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                          backgroundImage: user?.photoURL != null
                              ? CachedNetworkImageProvider(user!.photoURL!)
                              : null,
                          child: user?.photoURL == null
                              ? Text(
                                  displayName.isNotEmpty
                                      ? displayName[0].toUpperCase()
                                      : 'S',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Stats Grid ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: statsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                ),
                error: (_, __) => const SizedBox.shrink(),
                data: (stats) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: GridView.count(
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
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),

            // ── Liked Scholarships ────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Text('My Scholarships', style: AppTextStyles.headlineSmall),
                    const Spacer(),
                    TextButton(
                      onPressed: () {},
                      child: const Text('See all'),
                    ),
                  ],
                ),
              ),
            ),

            likedAsync.when(
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                ),
              ),
              error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
              data: (scholarships) {
                if (scholarships.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: _EmptySection(
                        icon: Icons.school_rounded,
                        message: 'No liked scholarships yet.\nStart swiping to find matches!',
                      ),
                    ),
                  );
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _ScholarshipListTile(scholarship: scholarships[i]),
                    childCount: scholarships.length,
                  ),
                );
              },
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
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
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
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

class _EmptySection extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptySection({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppColors.glassBorder),
          const SizedBox(height: 12),
          Text(
            message,
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
