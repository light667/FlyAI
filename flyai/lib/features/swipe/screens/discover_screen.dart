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
  final _pageController = PageController(viewportFraction: 0.88);
  int _currentIndex = 0;

  void _onAccept(ScholarshipModel scholarship) {
    // Bridge: set pending coaching scholarship → main_shell will switch to AI tab
    ref.read(pendingCoachingScholarshipProvider.notifier).state = scholarship;
    // Small visual delay so the user sees the accept animation
  }

  void _onRefuse(int total) {
    if (_currentIndex < total - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scholarshipsAsync = ref.watch(scholarshipProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Header ───────────────────────────────────────────────────────
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
                        'Discover',
                        style: AppTextStyles.headlineLarge
                            .copyWith(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        'Find your next opportunity',
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

          // ── Scholarship Cards ──────────────────────────────────────────────
          Expanded(
            child: scholarshipsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (_, __) => _ErrorView(
                  onRetry: () => ref.refresh(scholarshipProvider)),
              data: (scholarships) {
                if (scholarships.isEmpty) return const _EmptyView();
                return Column(
                  children: [
                    // Counter + progress
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: Row(
                        children: [
                          Text(
                            '${_currentIndex + 1} / ${scholarships.length}',
                            style: AppTextStyles.bodySmall,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: ((_currentIndex + 1) / scholarships.length),
                                minHeight: 3,
                                backgroundColor: AppColors.glassBorder,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    AppColors.primary),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: [AppColors.primary, Color(0xFF7C3AED)]),
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: Text(
                              '${scholarships[_currentIndex].compatibilityScore}% match',
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

                    // Cards PageView
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (i) =>
                            setState(() => _currentIndex = i),
                        itemCount: scholarships.length,
                        itemBuilder: (context, i) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: _ScholarshipCard(
                              scholarship: scholarships[i],
                              isActive: i == _currentIndex,
                            ),
                          );
                        },
                      ),
                    ),

                    // Accept / Refuse buttons
                    Padding(
                      padding: const EdgeInsets.fromLTRB(32, 16, 32, 24),
                      child: Row(
                        children: [
                          // Refuse
                          Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  _onRefuse(scholarships.length),
                              child: Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  color: AppColors.card,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                      color: AppColors.error.withValues(alpha: 0.4),
                                      width: 1.5),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.close_rounded,
                                        color: AppColors.error, size: 22),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Refuser',
                                      style: TextStyle(
                                        color: AppColors.error,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Accept
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _onAccept(scholarships[_currentIndex]),
                              child: Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      AppColors.success,
                                      Color(0xFF15803D)
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.success
                                          .withValues(alpha: 0.35),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.rocket_launch_rounded,
                                        color: Colors.white, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Accepter',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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

// ── Scholarship Card ───────────────────────────────────────────────────────

class _ScholarshipCard extends StatelessWidget {
  final ScholarshipModel scholarship;
  final bool isActive;
  const _ScholarshipCard({required this.scholarship, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isActive ? 1.0 : 0.95,
      duration: const Duration(milliseconds: 300),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            if (isActive)
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.15),
                blurRadius: 30,
                spreadRadius: 2,
                offset: const Offset(0, 12),
              ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
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
              child: scholarship.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: scholarship.imageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          _PlaceholderBg(country: scholarship.country),
                    )
                  : _PlaceholderBg(country: scholarship.country),
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
                      Colors.black.withValues(alpha: 0.75),
                      Colors.black.withValues(alpha: 0.95),
                    ],
                    stops: const [0.0, 0.35, 0.65, 1.0],
                  ),
                ),
              ),
            ),

            // Content
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Funding badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      scholarship.fundingType,
                      style: const TextStyle(
                          color: AppColors.success,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Title
                  Text(
                    scholarship.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // University
                  if (scholarship.university.isNotEmpty)
                    Text(
                      scholarship.university,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 14),

                  // Stats row
                  Row(
                    children: [
                      _InfoPill(Icons.location_on_rounded,
                          scholarship.country),
                      const SizedBox(width: 8),
                      if (scholarship.deadline != null)
                        _InfoPill(
                          Icons.schedule_rounded,
                          _deadlineLabel(scholarship.deadline!),
                          urgent: scholarship.isDeadlineSoon,
                        ),
                      const SizedBox(width: 8),
                      _InfoPill(Icons.school_outlined,
                          _shortDegree(scholarship.degreeLevel)),
                    ],
                  ),

                  // Fields
                  if (scholarship.fields.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: scholarship.fields.take(3).map((f) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.25),
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

            // Match score top-right
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
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
                      '${scholarship.compatibilityScore}%',
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
    );
  }

  String _deadlineLabel(DateTime d) {
    final diff = d.difference(DateTime.now()).inDays;
    if (diff < 0) return 'Expiré';
    if (diff == 0) return 'Aujourd\'hui!';
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
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
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
