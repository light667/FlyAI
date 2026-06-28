import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
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
  final CardSwiperController _cardController = CardSwiperController();

  @override
  void dispose() {
    _cardController.dispose();
    super.dispose();
  }

  void _onSwipeAction(ScholarshipModel scholarship, SwipeAction action) {
    ref.read(swipeNotifierProvider.notifier).swipe(scholarship, action);

    // Show feedback snackbar
    final (label, color, icon) = switch (action) {
      SwipeAction.like => ('Liked! ❤️', AppColors.success, Icons.favorite),
      SwipeAction.dislike => ('Passed', AppColors.textSecondary, Icons.close),
      SwipeAction.superLike => ('Priority! ⭐', AppColors.secondary, Icons.star),
    };

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(label),
        ]),
        duration: const Duration(milliseconds: 800),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scholarshipsAsync = ref.watch(scholarshipProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/symbol.png', height: 24),
            const SizedBox(width: 8),
            Text('Discover', style: AppTextStyles.headlineSmall),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: () {},
            tooltip: 'Filter',
          ),
        ],
      ),
      body: scholarshipsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => _ErrorView(onRetry: () => ref.refresh(scholarshipProvider)),
        data: (scholarships) {
          if (scholarships.isEmpty) {
            return _EmptyView();
          }
          return Column(
            children: [
              // Count indicator
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      '${scholarships.length} scholarships for you',
                      style: AppTextStyles.bodySmall,
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Text(
                        '${scholarships.first.compatibilityScore}% top match',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Card Swiper
              Expanded(
                child: CardSwiper(
                  controller: _cardController,
                  cardsCount: scholarships.length,
                  numberOfCardsDisplayed: scholarships.length.clamp(1, 3),
                  backCardOffset: const Offset(0, 30),
                  scale: 0.92,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  onSwipe: (prev, current, direction) {
                    final scholarship = scholarships[prev];
                    final action = switch (direction) {
                      CardSwiperDirection.right => SwipeAction.like,
                      CardSwiperDirection.left => SwipeAction.dislike,
                      CardSwiperDirection.top => SwipeAction.superLike,
                      _ => SwipeAction.dislike,
                    };
                    _onSwipeAction(scholarship, action);
                    return true;
                  },
                  onTapDisabled: () {},
                  cardBuilder: (context, index, percentThresholdX, percentThresholdY) {
                    return GestureDetector(
                      onTap: () => context.push(
                        '/home/scholarship/${scholarships[index].id}',
                        extra: scholarships[index],
                      ),
                      child: ScholarshipSwipeCard(scholarship: scholarships[index]),
                    );
                  },
                ),
              ),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ActionButton(
                      icon: Icons.close_rounded,
                      color: AppColors.error,
                      size: 52,
                      onTap: () => _cardController.swipe(CardSwiperDirection.left),
                    ),
                    _ActionButton(
                      icon: Icons.star_rounded,
                      color: AppColors.secondary,
                      size: 44,
                      onTap: () => _cardController.swipe(CardSwiperDirection.top),
                    ),
                    _ActionButton(
                      icon: Icons.favorite_rounded,
                      color: AppColors.success,
                      size: 52,
                      onTap: () => _cardController.swipe(CardSwiperDirection.right),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.card,
          border: Border.all(color: color.withOpacity(0.4), width: 1.5),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.2), blurRadius: 12, spreadRadius: 1),
          ],
        ),
        child: Icon(icon, color: color, size: size * 0.48),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.school_rounded, size: 80, color: AppColors.glassBorder),
          const SizedBox(height: 24),
          Text(AppStrings.noMoreScholarships, style: AppTextStyles.headlineMedium),
          const SizedBox(height: 8),
          Text(AppStrings.noMoreDesc, style: AppTextStyles.bodyMedium),
        ],
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
          const Icon(Icons.error_outline_rounded, size: 60, color: AppColors.error),
          const SizedBox(height: 16),
          Text('Failed to load scholarships', style: AppTextStyles.bodyMedium),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
