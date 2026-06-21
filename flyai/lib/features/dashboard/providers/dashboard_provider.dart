import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';

class DashboardStats {
  final int totalMatches;
  final int savedScholarships;
  final int activeApplications;
  final double avgCompatibility;

  const DashboardStats({
    required this.totalMatches,
    required this.savedScholarships,
    required this.activeApplications,
    required this.avgCompatibility,
  });
}

final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final user = AuthService.currentUser;
  if (user == null) {
    return const DashboardStats(
      totalMatches: 0,
      savedScholarships: 0,
      activeApplications: 0,
      avgCompatibility: 0,
    );
  }

  final uid = user.uid;

  final matches = await SupabaseService.client
      .from('matches')
      .select('compatibility_score')
      .eq('firebase_uid', uid);

  final saved = await SupabaseService.client
      .from('swipes')
      .select('id')
      .eq('firebase_uid', uid)
      .inFilter('action', ['like', 'super_like']);

  final apps = await SupabaseService.client
      .from('applications')
      .select('id')
      .eq('firebase_uid', uid)
      .neq('status', 'completed');

  final matchList = matches as List;
  final avgScore = matchList.isEmpty
      ? 0.0
      : matchList
              .map((m) => (m['compatibility_score'] as num).toDouble())
              .reduce((a, b) => a + b) /
          matchList.length;

  return DashboardStats(
    totalMatches: matchList.length,
    savedScholarships: (saved as List).length,
    activeApplications: (apps as List).length,
    avgCompatibility: avgScore,
  );
});

final recentActivityProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = AuthService.currentUser;
  if (user == null) return [];

  final res = await SupabaseService.client
      .from('swipes')
      .select('action, scholarship_id, bourses(titre, pays_destination)')
      .eq('firebase_uid', user.uid)
      .order('id', ascending: false)
      .limit(10);

  return List<Map<String, dynamic>>.from(res as List);
});
