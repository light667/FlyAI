import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../profile/models/profile_model.dart';
import '../models/scholarship_model.dart';
import '../repositories/scholarship_repository.dart';
import '../services/matching_engine.dart';

// ── Profile Provider ──────────────────────────────────────────────────────

final currentProfileProvider = FutureProvider<ProfileModel?>((ref) async {
  final user = AuthService.currentUser;
  if (user == null) return null;
  final json = await SupabaseService.fetchOne('profiles', 'firebase_uid', user.uid);
  if (json == null) return null;
  return ProfileModel.fromJson(json);
});

// ── Swipe History Provider ────────────────────────────────────────────────

final swipedIdsProvider = FutureProvider<Set<String>>((ref) async {
  final user = AuthService.currentUser;
  if (user == null) return {};
  final res = await SupabaseService.client
      .from('swipes')
      .select('scholarship_id')
      .eq('firebase_uid', user.uid);
  return (res as List).map((r) => r['scholarship_id'] as String).toSet();
});

// ── Scholarships + Matching Provider ─────────────────────────────────────

final scholarshipProvider = FutureProvider<List<ScholarshipModel>>((ref) async {
  final repo = ScholarshipRepository();
  final profile = await ref.watch(currentProfileProvider.future);
  final swipedIds = await ref.watch(swipedIdsProvider.future);

  final scholarships = await repo.fetchScholarships(excludeIds: swipedIds);

  if (profile == null) return scholarships;

  // Attach compatibility scores and sort
  final scored = scholarships
      .map((s) => s.copyWith(
            compatibilityScore: MatchingEngine.calculate(profile, s),
          ))
      .toList()
    ..sort((a, b) => b.compatibilityScore.compareTo(a.compatibilityScore));

  return scored;
});

// ── Liked Scholarships Provider ───────────────────────────────────────────

final likedScholarshipsProvider = FutureProvider<List<ScholarshipModel>>((ref) async {
  final user = AuthService.currentUser;
  if (user == null) return [];

  final res = await SupabaseService.client
      .from('swipes')
      .select('scholarship_id')
      .eq('firebase_uid', user.uid)
      .inFilter('action', ['like', 'super_like']);

  final ids = (res as List).map((r) => r['scholarship_id'] as String).toList();
  if (ids.isEmpty) return [];

  final scholarships = await SupabaseService.client
      .from('bourses')
      .select()
      .inFilter('id', ids);

  return (scholarships as List)
      .map((json) => ScholarshipModel.fromJson(json as Map<String, dynamic>))
      .toList();
});
