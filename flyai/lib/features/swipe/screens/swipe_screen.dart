import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_router.dart';
import '../../scholarships/models/scholarship_model.dart';
import '../../scholarships/providers/scholarship_provider.dart';
import '../providers/swipe_provider.dart';
import '../widgets/scholarship_swipe_card.dart';

class SwipeScreen extends ConsumerStatefulWidget {
  const SwipeScreen({super.key});
  @override
  ConsumerState<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeScreenState extends ConsumerState<SwipeScreen> {
  final _cardController = CardSwiperController();
  bool _isListMode = false;

  @override
  void dispose() {
    _cardController.dispose();
    super.dispose();
  }

  void _onSwipe(ScholarshipModel s, SwipeAction action) {
    ref.read(swipeNotifierProvider.notifier).swipe(s, action);
    final (msg, color) = switch (action) {
      SwipeAction.like => ('Liked! ❤️', AppColors.success),
      SwipeAction.dislike => ('Passed', AppColors.textSecondary),
      SwipeAction.superLike => ('Priority! ⭐', AppColors.secondary),
    };
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      duration: const Duration(milliseconds: 700),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scholarshipsAsync = ref.watch(scholarshipProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── App bar ───────────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Discover', style: AppTextStyles.headlineLarge.copyWith(fontWeight: FontWeight.w900)),
                      Text('Swipe to match', style: AppTextStyles.bodySmall),
                    ],
                  ),
                  const Spacer(),
                  // View toggle
                  GestureDetector(
                    onTap: () => setState(() => _isListMode = !_isListMode),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _isListMode ? AppColors.primary.withOpacity(0.15) : AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Icon(
                        _isListMode ? Icons.swipe_rounded : Icons.format_list_bulleted_rounded,
                        color: _isListMode ? AppColors.primary : AppColors.textSecondary,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => context.push(AppRoutes.settings),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Icon(Icons.settings_outlined, color: AppColors.textSecondary, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Content ────────────────────────────────────────────────────
          Expanded(
            child: scholarshipsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (e, _) => _ErrorView(onRetry: () => ref.refresh(scholarshipProvider)),
              data: (list) {
                if (list.isEmpty) return const _EmptyView();
                return _isListMode ? _ListView(scholarships: list) : _SwipeView(
                  scholarships: list,
                  controller: _cardController,
                  onSwipe: _onSwipe,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Swipe View ────────────────────────────────────────────────────────────

class _SwipeView extends ConsumerWidget {
  final List<ScholarshipModel> scholarships;
  final CardSwiperController controller;
  final void Function(ScholarshipModel, SwipeAction) onSwipe;

  const _SwipeView({required this.scholarships, required this.controller, required this.onSwipe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        // Top match badge
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            children: [
              Text(
                '${scholarships.length} opportunities for you',
                style: AppTextStyles.bodySmall,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFF7C3AED)],
                  ),
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8)],
                ),
                child: Text(
                  '${scholarships.first.compatibilityScore}% top match',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),

        // Card swiper
        Expanded(
          child: CardSwiper(
            controller: controller,
            cardsCount: scholarships.length,
            numberOfCardsDisplayed: scholarships.length.clamp(1, 3),
            backCardOffset: const Offset(0, 26),
            scale: 0.93,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            onSwipe: (prev, current, direction) {
              final action = switch (direction) {
                CardSwiperDirection.right => SwipeAction.like,
                CardSwiperDirection.left => SwipeAction.dislike,
                CardSwiperDirection.top => SwipeAction.superLike,
                _ => SwipeAction.dislike,
              };
              onSwipe(scholarships[prev], action);
              return true;
            },
            onTapDisabled: () {},
            cardBuilder: (context, index, _, __) {
              return GestureDetector(
                onTap: () => context.push('/home/scholarship/${scholarships[index].id}', extra: scholarships[index]),
                child: ScholarshipSwipeCard(scholarship: scholarships[index]),
              );
            },
          ),
        ),

        // Action buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ActionBtn(
                icon: Icons.close_rounded,
                color: AppColors.error,
                size: 56,
                onTap: () => controller.swipe(CardSwiperDirection.left),
                label: 'Pass',
              ),
              _ActionBtn(
                icon: Icons.star_rounded,
                color: AppColors.secondary,
                size: 46,
                onTap: () => controller.swipe(CardSwiperDirection.top),
                label: 'Priority',
              ),
              _ActionBtn(
                icon: Icons.favorite_rounded,
                color: AppColors.success,
                size: 56,
                onTap: () => controller.swipe(CardSwiperDirection.right),
                label: 'Like',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── List View ─────────────────────────────────────────────────────────────

class _ListView extends StatelessWidget {
  final List<ScholarshipModel> scholarships;
  const _ListView({required this.scholarships});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      itemCount: scholarships.length,
      itemBuilder: (context, i) {
        return GestureDetector(
          onTap: () => context.push('/home/scholarship/${scholarships[i].id}', extra: scholarships[i]),
          child: Container(
            height: 300,
            margin: const EdgeInsets.only(bottom: 16),
            child: ScholarshipSwipeCard(
              scholarship: scholarships[i],
              showSwipeHints: false,
            ),
          ),
        );
      },
    );
  }
}

// ── Action button ─────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onTap;
  final String label;
  const _ActionBtn({required this.icon, required this.color, required this.size, required this.onTap, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.card,
              border: Border.all(color: color.withOpacity(0.3), width: 1.5),
              boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 14, spreadRadius: 1)],
            ),
            child: Icon(icon, color: color, size: size * 0.46),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(color: color.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ── Empty & Error ──────────────────────────────────────────────────────────

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
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppColors.primary.withOpacity(0.2), Colors.transparent],
                ),
              ),
              child: const Icon(Icons.explore_rounded, size: 50, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            Text('All caught up!', style: AppTextStyles.headlineMedium.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(
              'You\'ve seen all available scholarships.\nNew ones are added regularly.',
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
          const Icon(Icons.wifi_off_rounded, size: 56, color: AppColors.error),
          const SizedBox(height: 16),
          Text('Failed to load scholarships', style: AppTextStyles.headlineSmall),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.refresh_rounded, color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Text('Retry', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
