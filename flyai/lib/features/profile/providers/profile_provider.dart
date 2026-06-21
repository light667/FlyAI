import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/profile_model.dart';
import '../repositories/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});

class ProfileNotifier extends AutoDisposeAsyncNotifier<ProfileModel?> {
  @override
  Future<ProfileModel?> build() async {
    final authState = ref.watch(authStateProvider);
    final user = authState.value;
    if (user == null) return null;

    final repo = ref.read(profileRepositoryProvider);
    return repo.getProfile(user.uid);
  }

  Future<void> updateProfile(ProfileModel profile) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      final repo = ref.read(profileRepositoryProvider);
      await repo.saveProfile(profile);
      // Invalidate profile exists provider
      ref.invalidate(profileExistsProvider);
      return profile;
    });
    state = result;
    if (result.hasError) {
      throw result.error!;
    }
  }

  Future<String?> uploadPhoto(List<int> bytes, String fileExtension, {bool updateDb = true}) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return null;

    final repo = ref.read(profileRepositoryProvider);
    final url = await repo.uploadProfilePhoto(user.uid, bytes, fileExtension);
    if (url != null && state.value != null && updateDb) {
      final updatedProfile = state.value!.copyWith(photoUrl: url);
      await updateProfile(updatedProfile);
    }
    return url;
  }

  Future<String?> uploadCV(List<int> bytes, String fileExtension, {bool updateDb = true}) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return null;

    final repo = ref.read(profileRepositoryProvider);
    final url = await repo.uploadCV(user.uid, bytes, fileExtension);
    if (url != null && state.value != null && updateDb) {
      final updatedProfile = state.value!.copyWith(cvUrl: url);
      await updateProfile(updatedProfile);
    }
    return url;
  }
}

final profileNotifierProvider =
    AutoDisposeAsyncNotifierProvider<ProfileNotifier, ProfileModel?>(
  ProfileNotifier.new,
);
