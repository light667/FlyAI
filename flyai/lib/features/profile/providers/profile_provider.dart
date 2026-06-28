import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/profile_model.dart';
import '../repositories/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});

// ── profileExistsProvider ─────────────────────────────────────────────────
// Vérifie si l'utilisateur courant possède déjà un profil Supabase.
// Utilisé par le router pour décider si on redirige vers /profile-setup ou /home.
// Était référencé dans ProfileNotifier mais jamais déclaré → crash runtime.
final profileExistsProvider = FutureProvider<bool>((ref) async {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  if (user == null) return false;

  final repo = ref.read(profileRepositoryProvider);
  final profile = await repo.getProfile(user.uid);
  return profile != null;
});

// ── ProfileNotifier ───────────────────────────────────────────────────────

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
    try {
      final repo = ref.read(profileRepositoryProvider);
      await repo.saveProfile(profile);
      ref.invalidate(profileExistsProvider);
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      Error.throwWithStackTrace(e, st);
    }
  }

  Future<String?> uploadPhoto(
    List<int> bytes,
    String fileExtension, {
    bool updateDb = true,
  }) async {
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

  Future<String?> uploadCV(
    List<int> bytes,
    String fileExtension, {
    bool updateDb = true,
  }) async {
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