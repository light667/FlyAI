import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../scholarships/models/scholarship_model.dart';

class ScholarshipSwipeCard extends StatelessWidget {
  final ScholarshipModel scholarship;
  final bool showSwipeHints;

  const ScholarshipSwipeCard({
    super.key,
    required this.scholarship,
    this.showSwipeHints = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Background image ─────────────────────────────────────────
          _buildBackground(),

          // ── Gradient overlay (bottom-heavy) ──────────────────────────
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.05),
                    Colors.black.withOpacity(0.65),
                    Colors.black.withOpacity(0.92),
                  ],
                  stops: const [0.0, 0.35, 0.7, 1.0],
                ),
              ),
            ),
          ),

          // ── Content overlay ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top row: match score + funding ───────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _MatchBadge(score: scholarship.compatibilityScore),
                    _FundingBadge(type: scholarship.fundingType),
                  ],
                ),

                const Spacer(),

                // ── Bottom content ────────────────────────────────────────
                // Country
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded, size: 13, color: Colors.white60),
                    const SizedBox(width: 4),
                    Text(
                      scholarship.country,
                      style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Title
                Text(
                  scholarship.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // University
                if (scholarship.university != null)
                  Text(
                    scholarship.university!,
                    style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 14),

                // Info chips row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _InfoChip(Icons.school_outlined, _shortenDegree(scholarship.degreeLevel), AppColors.primary),
                      const SizedBox(width: 8),
                      if (scholarship.deadline != null) ...[
                        _InfoChip(
                          Icons.schedule_rounded,
                          _formatDeadline(scholarship.deadline!),
                          scholarship.isDeadlineSoon ? AppColors.warning : Colors.white54,
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),

                // Swipe hints
                if (showSwipeHints) ...[
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _SwipeHint(Icons.close_rounded, AppColors.error, 'Pass'),
                      _SwipeHint(Icons.star_rounded, AppColors.secondary, 'Priority'),
                      _SwipeHint(Icons.favorite_rounded, AppColors.success, 'Like'),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    if (scholarship.imageUrl != null) {
      return CachedNetworkImage(
        imageUrl: scholarship.imageUrl!,
        fit: BoxFit.cover,
        placeholder: (_, __) => _PlaceholderBg(country: scholarship.country),
        errorWidget: (_, __, ___) => _PlaceholderBg(country: scholarship.country),
      );
    }
    return _PlaceholderBg(country: scholarship.country);
  }

  String _shortenDegree(String level) {
    if (level.length <= 16) return level;
    if (level.toLowerCase().contains('master')) return "Master's";
    if (level.toLowerCase().contains('bachelor')) return "Bachelor's";
    if (level.toLowerCase().contains('phd') || level.toLowerCase().contains('doctor')) return 'PhD';
    return '${level.substring(0, 14)}…';
  }

  String _formatDeadline(DateTime deadline) {
    final diff = deadline.difference(DateTime.now()).inDays;
    if (diff < 0) return 'Expired';
    if (diff == 0) return 'Today!';
    if (diff <= 30) return '$diff days';
    return '${(diff / 30).floor()}mo.';
  }
}

// ── Background placeholder ─────────────────────────────────────────────────

class _PlaceholderBg extends StatelessWidget {
  final String country;
  const _PlaceholderBg({required this.country});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school_rounded, size: 72, color: AppColors.primary.withOpacity(0.4)),
            const SizedBox(height: 12),
            Text(
              country,
              style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────

class _MatchBadge extends StatelessWidget {
  final int score;
  const _MatchBadge({required this.score});

  Color get _color {
    if (score >= 80) return AppColors.success;
    if (score >= 60) return AppColors.primary;
    if (score >= 40) return AppColors.secondary;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: _color.withOpacity(0.5)),
        boxShadow: [BoxShadow(color: _color.withOpacity(0.3), blurRadius: 10)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, size: 13, color: _color),
          const SizedBox(width: 4),
          Text(
            '$score% match',
            style: TextStyle(color: _color, fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _FundingBadge extends StatelessWidget {
  final String type;
  const _FundingBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final isFullyFunded = type.toLowerCase().contains('fully');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isFullyFunded ? AppColors.success.withOpacity(0.2) : Colors.white12,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(
          color: isFullyFunded ? AppColors.success.withOpacity(0.5) : Colors.white24,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.attach_money_rounded, size: 12,
              color: isFullyFunded ? AppColors.success : Colors.white70),
          const SizedBox(width: 3),
          Text(
            isFullyFunded ? 'Fully Funded' : type,
            style: TextStyle(
              color: isFullyFunded ? AppColors.success : Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _SwipeHint extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _SwipeHint(this.icon, this.color, this.label);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color.withOpacity(0.8)),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: color.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
