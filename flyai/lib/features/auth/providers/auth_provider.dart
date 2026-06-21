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

  /// Envoie un lien magique à [email].
  Future<void> sendSignInLink(String email) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await AuthService.sendSignInLinkToEmail(email);
    });
  }

  /// Complète la connexion avec le lien reçu par email.
  Future<void> completeSignInWithLink({
    required String email,
    required String emailLink,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await AuthService.signInWithEmailLink(
        email: email,
        emailLink: emailLink,
      );
    });
  }

  /// Inscription avec email + mot de passe.
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    String? fullName,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final result = await AuthService.signUpWithEmail(
        email: email,
        password: password,
      );
      if (fullName != null && fullName.isNotEmpty) {
        await result.user?.updateDisplayName(fullName);
      }
    });
  }

  /// Connexion avec email + mot de passe.
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await AuthService.signInWithEmail(email: email, password: password);
    });
  }

  /// Envoi d'un email de réinitialisation du mot de passe.
  Future<void> sendPasswordReset(String email) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await AuthService.sendPasswordReset(email);
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
  try {
    final profile = await SupabaseService.fetchOne(
      'profiles',
      'firebase_uid',
      user.uid,
    );
    return profile != null;
  } catch (_) {
    return false;
  }
});
