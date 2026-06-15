import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flyai/core/services/auth_service.dart';
import 'package:flyai/core/services/supabase_service.dart';

// ── Auth State Provider ───────────────────────────────────────────────────

final authStateProvider = StreamProvider<User?>((ref) {
  return AuthService.authStateChanges;
});

// ── Auth Notifier ─────────────────────────────────────────────────────────

class AuthNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final cred = await AuthService.signUpWithEmail(
        email: email,
        password: password,
      );
      // Update display name
      await cred.user?.updateDisplayName(fullName);
    });
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await AuthService.signInWithEmail(email: email, password: password);
    });
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await AuthService.signInWithGoogle();
    });
  }

  Future<void> signInWithApple() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await AuthService.signInWithApple();
    });
  }

  Future<void> sendPasswordReset(String email) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await AuthService.sendPasswordReset(email);
    });
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await AuthService.signOut();
    });
  }
}

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, void>(AuthNotifier.new);

// ── Profile exists check ──────────────────────────────────────────────────

final profileExistsProvider = FutureProvider<bool>((ref) async {
  final user = AuthService.currentUser;
  if (user == null) return false;
  final profile = await SupabaseService.fetchOne(
    'profiles',
    'firebase_uid',
    user.uid,
  );
  return profile != null;
});
