import '../../../core/services/supabase_service.dart';

class SwipeRepository {
  Future<void> saveSwipe({
    required String firebaseUid,
    required String scholarshipId,
    required String action,
  }) async {
    await SupabaseService.insert('swipes', {
      'firebase_uid': firebaseUid,
      'scholarship_id': scholarshipId,
      'action': action,
    });
  }

  Future<void> createMatch({
    required String firebaseUid,
    required String scholarshipId,
    required int compatibilityScore,
  }) async {
    await SupabaseService.insert('matches', {
      'firebase_uid': firebaseUid,
      'scholarship_id': scholarshipId,
      'compatibility_score': compatibilityScore,
    });
  }
}
