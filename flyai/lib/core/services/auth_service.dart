import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kEmailForSignInKey = 'emailForSignIn';

class AuthService {
  AuthService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  static User? get currentUser => _auth.currentUser;
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Email Magic Link ───────────────────────────────────────────────────────

  /// Sends a sign-in link to [email].
  /// The link will open the app at [continueUrl].
  static Future<void> sendSignInLinkToEmail(String email) async {
    final actionCodeSettings = ActionCodeSettings(
      // URL l'utilisateur sera redirigé après avoir cliqué le lien.
      // Doit être dans les domaines autorisés de Firebase Console.
      url: kIsWeb
          ? '${Uri.base.origin}/finish-sign-in'
          : 'https://flyai-org.firebaseapp.com/finish-sign-in',
      handleCodeInApp: true,
      androidPackageName: 'com.flyai.app',
      androidInstallApp: true,
      androidMinimumVersion: '21',
      iOSBundleId: 'com.flyai.app',
    );

    await _auth.sendSignInLinkToEmail(
      email: email.trim(),
      actionCodeSettings: actionCodeSettings,
    );

    // Sauvegarder l'email localement pour la vérification ultérieure.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kEmailForSignInKey, email.trim());
  }

  /// Retrieves the locally saved email for sign-in link verification.
  static Future<String?> getSavedEmailForSignIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kEmailForSignInKey);
  }

  /// Clears the saved email after successful sign-in.
  static Future<void> clearSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kEmailForSignInKey);
  }

  /// Returns true if [link] is a valid Firebase sign-in link.
  static bool isSignInWithEmailLink(String link) {
    return _auth.isSignInWithEmailLink(link);
  }

  /// Completes sign-in with the [email] and [emailLink] from the deep link.
  static Future<UserCredential> signInWithEmailLink({
    required String email,
    required String emailLink,
  }) async {
    final result = await _auth.signInWithEmailLink(
      email: email.trim(),
      emailLink: emailLink,
    );
    await clearSavedEmail();
    return result;
  }

  // ── Google ────────────────────────────────────────────────────────────────

  /// On web: uses redirect (évite le blocage COOP).
  /// On mobile: uses the native GoogleSignIn package.
  static Future<UserCredential?> signInWithGoogle() async {
    if (kIsWeb) {
      final googleProvider = GoogleAuthProvider();
      // Utiliser signInWithRedirect pour éviter l'erreur COOP popup.
      await _auth.signInWithRedirect(googleProvider);
      // Le résultat sera récupéré dans getRedirectResult() au démarrage.
      return null;
    } else {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // user cancelled

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return _auth.signInWithCredential(credential);
    }
  }

  /// Gets the result of a redirect-based sign-in (web only).
  /// Returns null if no redirect result is pending.
  static Future<UserCredential?> getRedirectResult() async {
    if (!kIsWeb) return null;
    try {
      final result = await _auth.getRedirectResult();
      if (result.user != null) return result;
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Apple ─────────────────────────────────────────────────────────────────

  static Future<UserCredential> signInWithApple() async {
    final appleProvider = AppleAuthProvider()
      ..addScope('email')
      ..addScope('name');
    return _auth.signInWithProvider(appleProvider);
  }

  // ── Email + Password ─────────────────────────────────────────────────────

  /// Creates a new account with [email] and [password].
  /// Sends a verification email after creation.
  static Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return result;
  }

  /// Signs in an existing user with [email] and [password].
  static Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Sends a password reset email to [email].
  static Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // ── Sign Out ──────────────────────────────────────────────────────────────

  static Future<void> signOut() async {
    if (!kIsWeb) await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String mapFirebaseError(FirebaseAuthException e, {bool fr = true}) {
    if (fr) {
      switch (e.code) {
        case 'user-not-found':
          return 'Aucun compte trouvé avec cet e-mail.';
        case 'email-already-in-use':
          return 'Un compte existe déjà avec cet e-mail.';
        case 'invalid-email':
          return 'Veuillez saisir une adresse e-mail valide.';
        case 'network-request-failed':
          return 'Erreur réseau. Vérifiez votre connexion.';
        case 'too-many-requests':
          return 'Trop de tentatives. Réessayez plus tard.';
        case 'invalid-action-code':
          return 'Lien expiré ou invalide. Redemandez un lien.';
        default:
          return e.message ?? 'Authentification échouée. Réessayez.';
      }
    } else {
      switch (e.code) {
        case 'user-not-found':
          return 'No account found with this email.';
        case 'email-already-in-use':
          return 'An account already exists with this email.';
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'network-request-failed':
          return 'Network error. Please check your connection.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        case 'invalid-action-code':
          return 'Link expired or invalid. Please request a new link.';
        default:
          return e.message ?? 'Authentication failed. Please try again.';
      }
    }
  }
}
