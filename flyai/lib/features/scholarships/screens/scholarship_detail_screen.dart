import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/primary_button.dart';
import '../../scholarships/models/scholarship_model.dart';
import '../../swipe/providers/swipe_provider.dart';
import '../../applications/providers/application_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';

class ScholarshipDetailScreen extends ConsumerWidget {
  final ScholarshipModel scholarship;

  const ScholarshipDetailScreen({super.key, required this.scholarship});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Hero App Bar ────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppColors.background,
            leading: GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: scholarship.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: scholarship.imageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _PlaceholderHero(scholarship: scholarship),
                    )
                  : _PlaceholderHero(scholarship: scholarship),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(scholarship.title,
                            style: AppTextStyles.displayMedium),
                      ),
                      const SizedBox(width: 12),
                      _CompatBadge(score: scholarship.compatibilityScore),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(scholarship.university, style: AppTextStyles.bodyMedium),
                  const SizedBox(height: 24),

                  // Quick stats row
                  _QuickStatsRow(scholarship: scholarship),
                  const SizedBox(height: 28),

                  // Description
                  _Section(
                    title: 'About This Scholarship',
                    child: Text(
                      scholarship.description.isNotEmpty
                          ? scholarship.description
                          : 'No description available.',
                      style: AppTextStyles.bodyMedium.copyWith(height: 1.6),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Fields
                  if (scholarship.fields.isNotEmpty) ...[
                    _Section(
                      title: 'Fields of Study',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: scholarship.fields
                            .map((f) => _Tag(label: f))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Requirements
                  if (scholarship.requirements.isNotEmpty) ...[
                    _Section(
                      title: 'Required Documents',
                      child: Column(
                        children: scholarship.requirements
                            .map((r) => _CheckItem(label: r))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Compatibility breakdown
                  _Section(
                    title: 'Your Compatibility',
                    child: _CompatBreakdown(scholarship: scholarship),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // ── Bottom Action Bar ─────────────────────────────────────────────────
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border(top: BorderSide(color: AppColors.glassBorder)),
        ),
        child: Row(
          children: [
            // Swipe actions
            _CircleAction(
              icon: Icons.close_rounded,
              color: AppColors.error,
              onTap: () {
                ref.read(swipeNotifierProvider.notifier).swipe(
                    scholarship, SwipeAction.dislike);
                context.pop();
              },
            ),
            const SizedBox(width: 12),
            _CircleAction(
              icon: Icons.star_rounded,
              color: AppColors.secondary,
              onTap: () {
                ref.read(swipeNotifierProvider.notifier).swipe(
                    scholarship, SwipeAction.superLike);
                context.pop();
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PrimaryButton(
                label: AppStrings.startApplication,
                icon: Icons.rocket_launch_rounded,
                onPressed: () async {
                  try {
                    await ref
                        .read(applicationNotifierProvider.notifier)
                        .startApplication(scholarship.id);
                    ref.invalidate(dashboardStatsProvider);
                  } catch (_) {}

                  if (scholarship.applicationUrl != null) {
                    final uri = Uri.parse(scholarship.applicationUrl!);
                    if (await canLaunchUrl(uri)) launchUrl(uri);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderHero extends StatelessWidget {
  final ScholarshipModel scholarship;
  const _PlaceholderHero({required this.scholarship});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.card,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.school_rounded, size: 72, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(scholarship.country, style: AppTextStyles.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _QuickStatsRow extends StatelessWidget {
  final ScholarshipModel scholarship;
  const _QuickStatsRow({required this.scholarship});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(label: 'Country', value: scholarship.country, icon: Icons.location_on_rounded),
        const SizedBox(width: 12),
        _StatCard(label: 'Funding', value: scholarship.fundingType, icon: Icons.attach_money_rounded),
        const SizedBox(width: 12),
        _StatCard(
          label: 'Deadline',
          value: scholarship.deadline != null
              ? '${scholarship.deadline!.day}/${scholarship.deadline!.month}/${scholarship.deadline!.year}'
              : 'N/A',
          icon: Icons.calendar_today_outlined,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(height: 6),
            Text(value,
                style: AppTextStyles.titleMedium, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(label, style: AppTextStyles.caption, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.headlineSmall),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  const _Tag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary)),
    );
  }
}

class _CheckItem extends StatelessWidget {
  final String label;
  const _CheckItem({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded, size: 18, color: AppColors.success),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: AppTextStyles.bodyMedium)),
        ],
      ),
    );
  }
}

class _CompatBadge extends StatelessWidget {
  final int score;
  const _CompatBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = score >= 70 ? AppColors.success : score >= 50 ? AppColors.primary : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Text('$score%', style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800)),
          Text('Match', style: TextStyle(color: color, fontSize: 10)),
        ],
      ),
    );
  }
}

class _CompatBreakdown extends StatelessWidget {
  final ScholarshipModel scholarship;
  const _CompatBreakdown({required this.scholarship});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          _CompatRow(label: 'Education Level', match: true),
          _CompatRow(label: 'Field of Study', match: scholarship.fields.isNotEmpty),
          _CompatRow(label: 'Target Country', match: true),
          _CompatRow(label: 'Language Requirements', match: true),
          _CompatRow(label: 'Nationality Eligible', match: true),
        ],
      ),
    );
  }
}

class _CompatRow extends StatelessWidget {
  final String label;
  final bool match;
  const _CompatRow({required this.label, required this.match});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            match ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 18,
            color: match ? AppColors.success : AppColors.error,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: AppTextStyles.bodyMedium)),
        ],
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _CircleAction({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.5), width: 1.5),
        ),
        child: Icon(icon, color: color),
      ),
    );
  }
}
