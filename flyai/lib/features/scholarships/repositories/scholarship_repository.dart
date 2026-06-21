import '../../../core/services/supabase_service.dart';
import '../models/scholarship_model.dart';

class ScholarshipRepository {
  static const _table = 'bourses';

  Future<List<ScholarshipModel>> fetchScholarships({
    int page = 0,
    int pageSize = 20,
    Set<String>? excludeIds,
  }) async {
    final client = SupabaseService.client;
    var query = client
        .from(_table)
        .select()
        .eq('active', true)
        .order('created_at', ascending: false)
        .range(page * pageSize, (page + 1) * pageSize - 1);

    final response = await query;
    final all = (response as List)
        .map((json) => ScholarshipModel.fromJson(json as Map<String, dynamic>))
        .toList();

    if (excludeIds != null && excludeIds.isNotEmpty) {
      return all.where((s) => !excludeIds.contains(s.id)).toList();
    }
    return all;
  }

  Future<ScholarshipModel?> fetchById(String id) async {
    final json = await SupabaseService.fetchOne(_table, 'id', id);
    if (json == null) return null;
    return ScholarshipModel.fromJson(json);
  }
}
