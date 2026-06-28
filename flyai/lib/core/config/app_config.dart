import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuration centralisée de l'application.
///
/// Stratégie double selon l'environnement :
///
/// ① Local (flutter run / flutter build debug)
///    → [dotenv] charge automatiquement `assets/.env`
///    → les valeurs sont lues depuis dotenv.env['KEY']
///
/// ② Production web (Firebase Hosting)
///    → `assets/.env` n'existe pas (gitignore) → la requête renvoie 404
///    → les valeurs viennent des constantes compilées via :
///       flutter build web --dart-define-from-file=dart_defines.json
///    → [String.fromEnvironment] est évalué au moment du build,
///       les secrets sont embarqués dans le JS (jamais servis en clair)
///
/// Ordre de priorité : dotenv > compile-time > chaîne vide (erreur visible).
class AppConfig {
  AppConfig._();

  // ── Constantes compilées (--dart-define-from-file) ──────────────────────
  // Vides si le build n'a pas fourni --dart-define → fallback sur dotenv.
  static const String _envSupabaseUrl =
      String.fromEnvironment('SUPABASE_URL');
  static const String _envSupabaseKey =
      String.fromEnvironment('SUPABASE_KEY');
  static const String _envGeminiKey =
      String.fromEnvironment('GEMINI_API_KEY');
  static const String _envMistralKey =
      String.fromEnvironment('MISTRAL_API_KEY');
  static const String _envGroqKey =
      String.fromEnvironment('GROQ_API_KEY');

  // ── Accesseurs (dotenv prioritaire, compile-time en fallback) ────────────

  static String get supabaseUrl =>
      _fromDotenvOr('SUPABASE_URL', _envSupabaseUrl);

  static String get supabaseKey =>
      _fromDotenvOr('SUPABASE_KEY', _envSupabaseKey);

  static String get geminiApiKey =>
      _fromDotenvOr('GEMINI_API_KEY', _envGeminiKey);

  static String get mistralApiKey =>
      _fromDotenvOr('MISTRAL_API_KEY', _envMistralKey);

  static String get groqApiKey =>
      _fromDotenvOr('GROQ_API_KEY', _envGroqKey);

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Retourne la valeur dotenv si disponible, sinon [compiledFallback].
  static String _fromDotenvOr(String key, String compiledFallback) {
    final dotenvValue = dotenv.env[key];
    if (dotenvValue != null && dotenvValue.isNotEmpty) return dotenvValue;
    return compiledFallback;
  }

  /// Vérifie que toutes les clés critiques sont présentes.
  /// Appeler dans main() en debug pour détecter les oublis tôt.
  static List<String> get missingKeys {
    final required = {
      'SUPABASE_URL': supabaseUrl,
      'SUPABASE_KEY': supabaseKey,
      'GEMINI_API_KEY': geminiApiKey,
    };
    return required.entries
        .where((e) => e.value.isEmpty)
        .map((e) => e.key)
        .toList();
  }
}
