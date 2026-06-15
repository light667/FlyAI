import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/auth_service.dart';
import '../models/application_model.dart';
import '../repositories/application_repository.dart';

final applicationRepositoryProvider = Provider<ApplicationRepository>((ref) {
  return ApplicationRepository();
});

class ApplicationNotifier extends AutoDisposeAsyncNotifier<List<ApplicationModel>> {
  @override
  Future<List<ApplicationModel>> build() async {
    final user = AuthService.currentUser;
    if (user == null) return [];

    final repo = ref.read(applicationRepositoryProvider);
    return repo.getApplications(user.uid);
  }

  Future<void> startApplication(String scholarshipId) async {
    final user = AuthService.currentUser;
    if (user == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(applicationRepositoryProvider);
      await repo.createApplication(firebaseUid: user.uid, scholarshipId: scholarshipId);
      return repo.getApplications(user.uid);
    });
  }

  Future<void> toggleChecklistItem(String applicationId, String key, bool value) async {
    final currentList = state.valueOrNull ?? [];
    final appIdx = currentList.indexWhere((a) => a.id == applicationId);
    if (appIdx < 0) return;

    final app = currentList[appIdx];
    final updatedChecklist = Map<String, bool>.from(app.checklist)..[key] = value;
    
    // Calculate progress percentage
    final completedCount = updatedChecklist.values.where((v) => v).length;
    final totalCount = updatedChecklist.length;
    final progress = totalCount > 0 ? ((completedCount / totalCount) * 100).round() : 0;

    final updatedApp = app.copyWith(
      checklist: updatedChecklist,
      progress: progress,
    );

    // Optimistic update
    state = AsyncData(
      List<ApplicationModel>.from(currentList)..[appIdx] = updatedApp,
    );

    try {
      final repo = ref.read(applicationRepositoryProvider);
      await repo.updateApplication(updatedApp);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      ref.invalidateSelf();
    }
  }

  Future<void> updateStatus(String applicationId, String status) async {
    final currentList = state.valueOrNull ?? [];
    final appIdx = currentList.indexWhere((a) => a.id == applicationId);
    if (appIdx < 0) return;

    final app = currentList[appIdx];
    final updatedApp = app.copyWith(status: status);

    state = AsyncData(
      List<ApplicationModel>.from(currentList)..[appIdx] = updatedApp,
    );

    try {
      final repo = ref.read(applicationRepositoryProvider);
      await repo.updateApplication(updatedApp);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      ref.invalidateSelf();
    }
  }

  Future<void> cancelApplication(String applicationId) async {
    final currentList = state.valueOrNull ?? [];
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(applicationRepositoryProvider);
      await repo.deleteApplication(applicationId);
      return currentList.where((a) => a.id != applicationId).toList();
    });
  }
}

final applicationNotifierProvider =
    AutoDisposeAsyncNotifierProvider<ApplicationNotifier, List<ApplicationModel>>(
  ApplicationNotifier.new,
);
