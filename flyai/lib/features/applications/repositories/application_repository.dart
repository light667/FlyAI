import '../../../core/services/supabase_service.dart';
import '../models/application_model.dart';

class ApplicationRepository {
  static const _table = 'applications';

  Future<List<ApplicationModel>> getApplications(String firebaseUid) async {
    try {
      // Try with join first
      final response = await SupabaseService.client
          .from(_table)
          .select('*, scholarships(*)')
          .eq('firebase_uid', firebaseUid)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => ApplicationModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Fallback: fetch without join (scholarships table may be empty)
      try {
        final response = await SupabaseService.client
            .from(_table)
            .select()
            .eq('firebase_uid', firebaseUid)
            .order('created_at', ascending: false);

        return (response as List)
            .map((json) => ApplicationModel.fromJson(json as Map<String, dynamic>))
            .toList();
      } catch (e) {
        // ignore: avoid_print
        print('[ApplicationRepository] getApplications error: $e');
        return [];
      }
    }
  }

  Future<ApplicationModel> createApplication({
    required String firebaseUid,
    required String scholarshipId,
  }) async {
    // Check if application already exists
    final existing = await SupabaseService.client
        .from(_table)
        .select()
        .eq('firebase_uid', firebaseUid)
        .eq('scholarship_id', scholarshipId)
        .maybeSingle();

    if (existing != null) {
      return ApplicationModel.fromJson(existing);
    }

    final defaultChecklist = {
      'CV': false,
      'Passport': false,
      'Degree Certificate': false,
      'Academic Transcript': false,
      'Recommendation Letter': false,
      'Motivation Letter': false,
    };

    final Map<String, dynamic> data = {
      'firebase_uid': firebaseUid,
      'scholarship_id': scholarshipId,
      'status': 'draft',
      'progress': 0,
      'checklist': defaultChecklist,
    };

    final inserted = await SupabaseService.client
        .from(_table)
        .insert(data)
        .select()
        .single();

    return ApplicationModel.fromJson(inserted);
  }

  Future<void> updateApplication(ApplicationModel application) async {
    await SupabaseService.update(
      _table,
      application.toJson(),
      'id',
      application.id,
    );
  }

  Future<void> deleteApplication(String id) async {
    await SupabaseService.delete(_table, 'id', id);
  }
}
