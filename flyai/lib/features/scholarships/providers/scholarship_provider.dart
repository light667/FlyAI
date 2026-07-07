import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../profile/models/profile_model.dart';
import '../models/scholarship_model.dart';
import '../repositories/scholarship_repository.dart';
import '../services/matching_engine.dart';

// ── Swipe history ─────────────────────────────────────────────────────────

final swipedIdsProvider = FutureProvider<Set<String>>((ref) async {
  // Watch auth state so this re-runs when user signs in
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
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
// Root cause of 0% scores:
//   The old code used AuthService.currentUser (synchronous getter) which
//   returns null during the ~200ms Firebase Auth restore-from-storage phase.
//   When null, the scoring block is skipped → all scholarships keep their
//   default compatibilityScore = 0.
//
// Fix:
//   Watch authStateProvider (a StreamProvider) instead. Riverpod will
//   automatically re-run this FutureProvider once the user is authenticated,
//   ensuring the profile is always loaded before scoring runs.

final scholarshipProvider =
    FutureProvider<List<ScholarshipModel>>((ref) async {
  // 1. Wait for a confirmed authenticated user
  final authState = ref.watch(authStateProvider);
  final user = authState.value;

  final repo = ScholarshipRepository();
  final swipedIds = await ref.watch(swipedIdsProvider.future);

  // 2. Fetch scholarships (no scoring yet)
  final scholarships = await repo.fetchScholarships(excludeIds: swipedIds);

  if (user == null) {
    // Auth not yet restored — return unscored list; provider will rebuild
    // automatically once authStateProvider emits the authenticated user.
    return scholarships;
  }

  // 3. Load profile from Supabase
  ProfileModel? profile;
  try {
    final profileJson = await SupabaseService.fetchOne(
        'profiles', 'firebase_uid', user.uid);
    if (profileJson != null) {
      profile = ProfileModel.fromJson(profileJson);
    }
  } catch (e) {
    // Profile not yet created (new user still in onboarding)
  }

  if (profile == null) {
    // No profile yet → return in quality-score order without matching
    return scholarships;
  }

  // 4. Score every scholarship against the profile
  final scored = scholarships.map((s) {
    final score = MatchingEngine.calculate(profile!, s);
    return s.copyWith(compatibilityScore: score);
  }).toList();

  // 5. Sort descending (highest match first)
  scored.sort((a, b) => b.compatibilityScore.compareTo(a.compatibilityScore));
  return scored;
});

// ── Liked scholarships ────────────────────────────────────────────────────

final likedScholarshipsProvider =
    FutureProvider<List<ScholarshipModel>>((ref) async {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
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

    // Try 'scholarships' table first, fall back to 'bourses'
    List<dynamic> rows = [];
    try {
      rows = await SupabaseService.client
          .from('scholarships')
          .select()
          .inFilter('id', ids);
    } catch (_) {
      try {
        rows = await SupabaseService.client
            .from('bourses')
            .select()
            .inFilter('id', ids);
      } catch (_) {}
    }

    return rows
        .map((json) => ScholarshipModel.fromJson(json as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
});

// ── Current profile (for matching engine in other providers) ──────────────

final currentProfileProvider = FutureProvider<ProfileModel?>((ref) async {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  if (user == null) return null;

  try {
    final json = await SupabaseService.fetchOne(
        'profiles', 'firebase_uid', user.uid);
    if (json == null) return null;
    return ProfileModel.fromJson(json);
  } catch (_) {
    return null;
  }
});
