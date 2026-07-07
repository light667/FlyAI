import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../profile/models/profile_model.dart';
import '../../profile/providers/profile_provider.dart';
import '../models/scholarship_model.dart';
import '../repositories/scholarship_repository.dart';
import '../services/matching_engine.dart';

// ── Swipe history ─────────────────────────────────────────────────────────

final swipedIdsProvider = FutureProvider<Set<String>>((ref) async {
  // profileNotifierProvider rebuilds when auth state changes, so watching it
  // here ensures swipedIds also re-fetches after login.
  final profileAsync = ref.watch(profileNotifierProvider);
  final _ = profileAsync; // just to register the dependency

  final user = AuthService.currentUser;
  if (user == null) return {};
  try {
    final res = await SupabaseService.client
        .from('swipes')
        .select('scholarship_id')
        .eq('firebase_uid', user.uid);
    return (res as List)
        .map((r) => r['scholarship_id'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
  } catch (_) {
    return {};
  }
});

// ── Scholarships + matching ───────────────────────────────────────────────
//
// Root cause of 0% scores (race condition):
//   Firebase Auth restores the session ~200ms after app launch.
//   During that window AuthService.currentUser == null → profile not loaded
//   → scoring skipped → all scholarships keep compatibilityScore = 0.
//
// Fix: watch profileNotifierProvider instead of reading AuthService directly.
//   profileNotifierProvider already watches authStateProvider internally.
//   When the user authenticates, profileNotifierProvider re-runs, which
//   makes scholarshipProvider re-run too → profile is available → scores
//   are calculated correctly.

final scholarshipProvider =
    FutureProvider<List<ScholarshipModel>>((ref) async {
  // 1. Watch the profile provider — this creates a reactive dependency.
  //    The future completes once the profile has loaded (or null if absent).
  ProfileModel? profile;
  try {
    profile = await ref.watch(profileNotifierProvider.future);
  } catch (_) {
    // Profile not yet created (new user in onboarding) — score-less list.
  }

  // 2. Fetch swiped IDs so already-seen scholarships are excluded.
  final swipedIds = await ref.watch(swipedIdsProvider.future);

  // 3. Fetch scholarships from Supabase.
  final repo = ScholarshipRepository();
  final scholarships = await repo.fetchScholarships(excludeIds: swipedIds);

  // 4. No profile → return in DB order (quality_score desc from repository).
  if (profile == null) return scholarships;

  // 5. Score every scholarship against the student profile.
  final scored = scholarships.map((s) {
    final score = MatchingEngine.calculate(profile!, s);
    return s.copyWith(compatibilityScore: score);
  }).toList();

  // 6. Sort descending — highest match first.
  scored.sort((a, b) => b.compatibilityScore.compareTo(a.compatibilityScore));
  return scored;
});

// ── Liked scholarships ────────────────────────────────────────────────────

final likedScholarshipsProvider =
    FutureProvider<List<ScholarshipModel>>((ref) async {
  // Re-run when profile (and thus auth) changes.
  final _ = ref.watch(profileNotifierProvider);

  final user = AuthService.currentUser;
  if (user == null) return [];

  try {
    final res = await SupabaseService.client
        .from('swipes')
        .select('scholarship_id')
        .eq('firebase_uid', user.uid)
        .inFilter('action', ['like', 'super_like']);

    final ids = (res as List)
        .map((r) => r['scholarship_id'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toList();

    if (ids.isEmpty) return [];

    // Try the scholarships table first, then fall back to bourses.
    for (final table in ['scholarships', 'bourses']) {
      try {
        final rows = await SupabaseService.client
            .from(table)
            .select()
            .inFilter('id', ids);
        if ((rows as List).isNotEmpty) {
          return rows
              .map((j) =>
                  ScholarshipModel.fromJson(j as Map<String, dynamic>))
              .toList();
        }
      } catch (_) {}
    }
    return [];
  } catch (_) {
    return [];
  }
});

// ── Current profile convenience provider ──────────────────────────────────

final currentProfileProvider = FutureProvider<ProfileModel?>((ref) async {
  return ref.watch(profileNotifierProvider.future);
});