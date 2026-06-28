import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../scholarships/models/scholarship_model.dart';

class ScholarshipSwipeCard extends StatelessWidget {
  final ScholarshipModel scholarship;

  const ScholarshipSwipeCard({super.key, required this.scholarship});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: AppColors.card,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Image ─────────────────────────────────────────────────────
          Expanded(
            flex: 5,
            child: Stack(
              fit: StackFit.expand,
              children: [
                scholarship.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: scholarship.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => _placeholderImage(),
                        errorWidget: (_, __, ___) => _placeholderImage(),
                      )
                    : _placeholderImage(),

                // Gradient overlay
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppColors.card.withValues(alpha: 0.9),
                        ],
                        stops: const [0.5, 1.0],
                      ),
                    ),
                  ),
                ),

                // Compatibility badge — top-right
                Positioned(
                  top: 12,
                  right: 12,
                  child: _CompatibilityBadge(score: scholarship.compatibilityScore),
                ),

                // Country chip — bottom-left
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: _CountryChip(country: scholarship.country),
                ),
              ],
            ),
          ),

          // ── Info ───────────────────────────────────────────────────────
          // Root cause of overflow:
          //   • Column had mainAxisSize: MainAxisSize.min, which prevents
          //     Spacer() from working — the Column tried to be as small as
          //     its children while Spacer pushed to expand → conflict.
          //   • Fix: remove mainAxisSize (defaults to max), so the Column
          //     fills the Expanded parent and MainAxisAlignment.spaceBetween
          //     pushes swipe hints to the bottom without needing Spacer.
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                // mainAxisSize defaults to max → fills the Expanded height
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top section: title + university + chips
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        scholarship.title,
                        style: AppTextStyles.titleLarge, // 16px — fits 1 line
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        scholarship.university,
                        style: AppTextStyles.bodySmall, // 12px
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      // Chips row — horizontal scroll prevents RunFlex issues
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _InfoChip(
                              icon: Icons.school_outlined,
                              label: scholarship.degreeLevel.length > 18
                                  ? '${scholarship.degreeLevel.substring(0, 16)}…'
                                  : scholarship.degreeLevel,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            _InfoChip(
                              icon: Icons.attach_money_rounded,
                              label: scholarship.fundingType,
                              color: AppColors.success,
                            ),
                            if (scholarship.deadline != null) ...[
                              const SizedBox(width: 6),
                              _InfoChip(
                                icon: Icons.calendar_today_outlined,
                                label: _formatDeadline(scholarship.deadline!),
                                color: scholarship.isDeadlineSoon
                                    ? AppColors.warning
                                    : AppColors.textSecondary,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Bottom section: swipe hints (pushed down by spaceBetween)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _SwipeHint(
                        icon: Icons.close_rounded,
                        color: AppColors.error,
                        label: 'Pass',
                      ),
                      _SwipeHint(
                        icon: Icons.star_rounded,
                        color: AppColors.secondary,
                        label: 'Priority',
                      ),
                      _SwipeHint(
                        icon: Icons.favorite_rounded,
                        color: AppColors.success,
                        label: 'Like',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderImage() {
    return Container(
      color: AppColors.background,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.school_rounded, size: 56, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(scholarship.country, style: AppTextStyles.bodyMedium),
          ],
        ),
      ),
    );
  }

  String _formatDeadline(DateTime deadline) {
    final diff = deadline.difference(DateTime.now()).inDays;
    if (diff < 0) return 'Expired';
    if (diff == 0) return 'Today!';
    if (diff <= 30) return '$diff days';
    final months = (diff / 30).floor();
    return '$months mo.';
  }
}

// ── _CompatibilityBadge ────────────────────────────────────────────────────

class _CompatibilityBadge extends StatelessWidget {
  final int score;
  const _CompatibilityBadge({required this.score});

  Color get _color {
    if (score >= 80) return AppColors.success;
    if (score >= 60) return AppColors.primary;
    if (score >= 40) return AppColors.secondary;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: _color.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(color: _color.withValues(alpha: 0.2), blurRadius: 6),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, size: 12, color: _color),
          const SizedBox(width: 3),
          Text(
            '$score%',
            style: TextStyle(
              color: _color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── _CountryChip ───────────────────────────────────────────────────────────

class _CountryChip extends StatelessWidget {
  final String country;
  const _CountryChip({required this.country});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on_rounded, size: 11, color: AppColors.textSecondary),
          const SizedBox(width: 3),
          Text(country, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

// ── _InfoChip ──────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── _SwipeHint ─────────────────────────────────────────────────────────────

class _SwipeHint extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _SwipeHint({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color.withValues(alpha: 0.6), size: 16),
        const SizedBox(height: 1),
        Text(
          label,
          style: TextStyle(
            color: color.withValues(alpha: 0.6),
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}