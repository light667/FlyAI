import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_router.dart';
import '../../scholarships/models/scholarship_model.dart';
import '../../scholarships/providers/scholarship_provider.dart';
import '../../ai_assistant/providers/scholarship_coaching_provider.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});
  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _scrollCtrl = ScrollController();

  void _onAccept(ScholarshipModel scholarship) {
    ref.read(pendingCoachingScholarshipProvider.notifier).state = scholarship;
  }

  void _onRefuse(ScholarshipModel scholarship) {
    // Nothing persistent — just visual, user can scroll past it
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scholarshipsAsync = ref.watch(scholarshipProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Header ─────────────────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Découvrir',
                        style: AppTextStyles.headlineLarge
                            .copyWith(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        'Trouve ta prochaine opportunité',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => context.push(AppRoutes.settings),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Icon(Icons.settings_outlined,
                          color: AppColors.textSecondary, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Scholarship Cards Horizontal Scroll ───────────────────────────
          Expanded(
            child: scholarshipsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (_, __) => _ErrorView(
                  onRetry: () => ref.refresh(scholarshipProvider)),
              data: (scholarships) {
                if (scholarships.isEmpty) return const _EmptyView();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sub-header: count + top match score
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(24, 14, 24, 8),
                      child: Row(
                        children: [
                          Text(
                            '${scholarships.length} bourses disponibles',
                            style: AppTextStyles.bodySmall,
                          ),
                          const Spacer(),
                          if (scholarships.first.compatibilityScore > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                    colors: [AppColors.primary, Color(0xFF7C3AED)]),
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: Text(
                                'Meilleur match : ${scholarships.first.compatibilityScore}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Horizontal scrollable list of scholarship cards
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // On wide screens (>700px): show 2 cards; on narrow: 1 card
                          final isWide = constraints.maxWidth > 700;
                          final cardWidth = isWide
                              ? (constraints.maxWidth / 2) - 24
                              : constraints.maxWidth - 40;

                          return ListView.separated(
                            controller: _scrollCtrl,
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                            itemCount: scholarships.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 16),
                            itemBuilder: (context, i) {
                              return SizedBox(
                                width: cardWidth,
                                child: _ScholarshipCard(
                                  scholarship: scholarships[i],
                                  onAccept: () => _onAccept(scholarships[i]),
                                  onRefuse: () => _onRefuse(scholarships[i]),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    SizedBox(height: MediaQuery.of(context).padding.bottom + 90),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Scholarship Card ────────────────────────────────────────────────────────

class _ScholarshipCard extends StatefulWidget {
  final ScholarshipModel scholarship;
  final VoidCallback onAccept;
  final VoidCallback onRefuse;

  const _ScholarshipCard({
    required this.scholarship,
    required this.onAccept,
    required this.onRefuse,
  });

  @override
  State<_ScholarshipCard> createState() => _ScholarshipCardState();
}

class _ScholarshipCardState extends State<_ScholarshipCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scholarship;

    return GestureDetector(
      onTap: () => context.push('/home/scholarship/${s.id}', extra: s),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.12),
            blurRadius: 30,
            spreadRadius: 2,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: s.imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: s.imageUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        _PlaceholderBg(country: s.country),
                  )
                : _PlaceholderBg(country: s.country),
          ),

          // Gradient overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.7),
                    Colors.black.withValues(alpha: 0.96),
                  ],
                  stops: const [0.0, 0.3, 0.58, 1.0],
                ),
              ),
            ),
          ),

          // Card content
          Positioned.fill(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top: match score badge
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    children: [
                      // Funding badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(
                              color: AppColors.success.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          s.fundingType,
                          style: const TextStyle(
                              color: AppColors.success,
                              fontSize: 11,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      const Spacer(),
                      // Match score
                      AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (_, child) => Transform.scale(
                          scale: s.compatibilityScore > 70
                              ? _pulseAnim.value
                              : 1.0,
                          child: child,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: s.compatibilityScore > 0
                                ? const LinearGradient(
                                    colors: [AppColors.primary, Color(0xFF7C3AED)])
                                : null,
                            color: s.compatibilityScore == 0
                                ? Colors.black.withValues(alpha: 0.5)
                                : null,
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.bolt_rounded,
                                  size: 13, color: Colors.white70),
                              const SizedBox(width: 3),
                              Text(
                                '${s.compatibilityScore}% match',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Bottom info
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title
                      Text(
                        s.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (s.university.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          s.university,
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 10),

                      // Stats row
                      Row(
                        children: [
                          _InfoPill(Icons.location_on_rounded, s.country),
                          const SizedBox(width: 8),
                          if (s.deadline != null)
                            _InfoPill(
                              Icons.schedule_rounded,
                              _deadlineLabel(s.deadline!),
                              urgent: s.isDeadlineSoon,
                            ),
                          const SizedBox(width: 8),
                          _InfoPill(Icons.school_outlined,
                              _shortDegree(s.degreeLevel)),
                        ],
                      ),

                      // Fields
                      if (s.fields.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: s.fields.take(3).map((f) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary
                                    .withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                f,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600),
                              ),
                            );
                          }).toList(),
                        ),
                      ],

                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  String _deadlineLabel(DateTime d) {
    final diff = d.difference(DateTime.now()).inDays;
    if (diff < 0) return 'Expiré';
    if (diff == 0) return "Aujourd'hui!";
    if (diff <= 30) return '$diff jours';
    return '${(diff / 30).floor()} mois';
  }

  String _shortDegree(String level) {
    if (level.toLowerCase().contains('master')) return "Master's";
    if (level.toLowerCase().contains('bachelor')) return "Bachelor's";
    if (level.toLowerCase().contains('phd') ||
        level.toLowerCase().contains('doctor')) return 'PhD';
    return level.length > 12 ? '${level.substring(0, 10)}…' : level;
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool urgent;
  const _InfoPill(this.icon, this.label, {this.urgent = false});

  @override
  Widget build(BuildContext context) {
    final color = urgent ? AppColors.warning : Colors.white60;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

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
            Icon(Icons.school_rounded,
                size: 72,
                color: AppColors.primary.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(country,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.explore_rounded,
                size: 64, color: AppColors.primary),
            const SizedBox(height: 20),
            Text('Aucune bourse disponible',
                style: AppTextStyles.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Reviens plus tard pour de nouvelles opportunités.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded,
              size: 56, color: AppColors.error),
          const SizedBox(height: 16),
          Text('Échec du chargement', style: AppTextStyles.headlineSmall),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded,
                      color: AppColors.primary, size: 18),
                  SizedBox(width: 8),
                  Text('Réessayer',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
