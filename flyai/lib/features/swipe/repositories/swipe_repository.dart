import 'package:flutter/foundation.dart';
import '../../../core/services/supabase_service.dart';

class SwipeRepository {
  static const _swipesTable  = 'swipes';
  static const _matchesTable = 'matches';

  // UUID v4 pattern required by PostgreSQL UUID column type.
  static final _uuidRegex = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  static bool _isValidUuid(String id) => _uuidRegex.hasMatch(id);

  // ── Swipe ─────────────────────────────────────────────────────────────────

  /// Saves a swipe action.
  /// Silently skips scholarships with non-UUID IDs (local/mock data).
  /// Uses [debugPrint] instead of [assert] so debug builds don't crash.
  Future<void> saveSwipe({
    required String firebaseUid,
    required String scholarshipId,
    required String action,
  }) async {
    if (!_isValidUuid(scholarshipId)) {
      // Log in debug only — never crash the UI over a skipped swipe.
      debugPrint(
        '[SwipeRepository.saveSwipe] scholarshipId "$scholarshipId" '
        'is not a valid UUID — swipe not persisted. '
        'Run the data pipeline to import real Supabase-generated UUIDs.',
      );
      return;
    }

    await SupabaseService.insert(_swipesTable, {
      'firebase_uid':   firebaseUid,
      'scholarship_id': scholarshipId,
      'action':         action,
    });
  }

  // ── Match ─────────────────────────────────────────────────────────────────

  /// Creates a match record for like / super_like actions.
  Future<void> createMatch({
    required String firebaseUid,
    required String scholarshipId,
    required int compatibilityScore,
  }) async {
    if (!_isValidUuid(scholarshipId)) {
      debugPrint(
        '[SwipeRepository.createMatch] scholarshipId "$scholarshipId" '
        'is not a valid UUID — match not persisted.',
      );
      return;
    }

    await SupabaseService.insert(_matchesTable, {
      'firebase_uid':        firebaseUid,
      'scholarship_id':      scholarshipId,
      'compatibility_score': compatibilityScore,
    });
  }

  // ── Queries ───────────────────────────────────────────────────────────────

  /// Returns IDs of scholarships already swiped by the user.
  Future<List<String>> getSwipedScholarshipIds(String firebaseUid) async {
    try {
      final rows = await SupabaseService.fetchAll(
        _swipesTable,
        filters: {'firebase_uid': firebaseUid},
        limit: 500,
      );
      return rows
          .map((r) => r['scholarship_id'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
