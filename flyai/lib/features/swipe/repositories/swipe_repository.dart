import '../../../core/services/supabase_service.dart';

class SwipeRepository {
  static const _swipesTable = 'swipes';
  static const _matchesTable = 'matches';

  // PostgreSQL UUID v4 format — toute valeur hors ce pattern est rejetée
  // avec le code d'erreur 22P02 ("invalid input syntax for type uuid").
  static final _uuidRegex = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  static bool _isValidUuid(String id) => _uuidRegex.hasMatch(id);

  // ── Swipe ─────────────────────────────────────────────────────────────────

  /// Enregistre l'action de swipe (like / dislike / super_like).
  /// Ignore silencieusement les bourses dont l'id n'est pas un UUID Supabase
  /// (ex : données locales/mock au format "fly_xxxxxxx").
  Future<void> saveSwipe({
    required String firebaseUid,
    required String scholarshipId,
    required String action,
  }) async {
    if (!_isValidUuid(scholarshipId)) {
      assert(
        false,
        '[SwipeRepository.saveSwipe] scholarshipId "$scholarshipId" '
        'is not a valid UUID — swipe not persisted.',
      );
      return;
    }

    await SupabaseService.insert(_swipesTable, {
      'firebase_uid': firebaseUid,
      'scholarship_id': scholarshipId,
      'action': action,
    });
  }

  // ── Match ─────────────────────────────────────────────────────────────────

  /// Crée un match dans la table [matches] lorsque l'utilisateur like ou
  /// super-like une bourse.
  /// Appelé par [swipe_provider.dart] après [saveSwipe] pour les actions
  /// 'like' et 'super_like'.
  Future<void> createMatch({
    required String firebaseUid,
    required String scholarshipId,
    required int compatibilityScore,
  }) async {
    if (!_isValidUuid(scholarshipId)) {
      assert(
        false,
        '[SwipeRepository.createMatch] scholarshipId "$scholarshipId" '
        'is not a valid UUID — match not persisted.',
      );
      return;
    }

    await SupabaseService.insert(_matchesTable, {
      'firebase_uid': firebaseUid,
      'scholarship_id': scholarshipId,
      'compatibility_score': compatibilityScore,
    });
  }

  // ── Queries ───────────────────────────────────────────────────────────────

  /// Retourne les IDs des bourses déjà swipées par l'utilisateur.
  /// Utilisé par le scholarship provider pour exclure les cartes déjà vues.
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