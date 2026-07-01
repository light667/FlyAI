import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/auth_service.dart';
import '../../scholarships/models/scholarship_model.dart';
import '../../scholarships/providers/scholarship_provider.dart';
import '../../applications/providers/application_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../repositories/swipe_repository.dart';

enum SwipeAction { like, dislike, superLike }

final swipeRepositoryProvider = Provider<SwipeRepository>((ref) {
  return SwipeRepository();
});

class SwipeNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> swipe(ScholarshipModel scholarship, SwipeAction action) async {
    final user = AuthService.currentUser;
    if (user == null) return;

    final actionStr = switch (action) {
      SwipeAction.like => 'like',
      SwipeAction.dislike => 'dislike',
      SwipeAction.superLike => 'super_like',
    };

    final repo = ref.read(swipeRepositoryProvider);

    await repo.saveSwipe(
      firebaseUid: user.uid,
      scholarshipId: scholarship.id,
      action: actionStr,
    );

    // If liked/super-liked → create match with compatibility score AND create draft application
    if (action == SwipeAction.like || action == SwipeAction.superLike) {
      await repo.createMatch(
        firebaseUid: user.uid,
        scholarshipId: scholarship.id,
        compatibilityScore: scholarship.compatibilityScore,
      );

      try {
        final appRepo = ref.read(applicationRepositoryProvider);
        await appRepo.createApplication(
          firebaseUid: user.uid,
          scholarshipId: scholarship.id,
        );
      } catch (_) {}
    }

    // Invalidate swipe history, scholarship list, liked list, dashboard stats, and applications
    ref.invalidate(swipedIdsProvider);
    ref.invalidate(scholarshipProvider);
    ref.invalidate(likedScholarshipsProvider);
    ref.invalidate(dashboardStatsProvider);
    ref.invalidate(applicationNotifierProvider);
  }
}

final swipeNotifierProvider =
    AsyncNotifierProvider<SwipeNotifier, void>(SwipeNotifier.new);
