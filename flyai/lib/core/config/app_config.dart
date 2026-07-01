/// Configuration centralisée — constantes compilées uniquement.
///
/// Les valeurs sont injectées au moment du build via :
///   flutter run   --dart-define-from-file=dart_defines.json
///   flutter build --dart-define-from-file=dart_defines.json
///
/// Aucun fichier .env n'est chargé au runtime.
/// Aucune dépendance flutter_dotenv.
class AppConfig {
  AppConfig._();

  static const String supabaseUrl =
      String.fromEnvironment('SUPABASE_URL');

  static const String supabaseKey =
      String.fromEnvironment('SUPABASE_KEY');

  static const String geminiApiKey =
      String.fromEnvironment('GEMINI_API_KEY');

  static const String mistralApiKey =
      String.fromEnvironment('MISTRAL_API_KEY');

  static const String groqApiKey =
      String.fromEnvironment('GROQ_API_KEY');

  /// Retourne les clés manquantes (valeur vide = non injectée au build).
  /// Appeler en debug dans main() pour un feedback immédiat.
  static List<String> get missingKeys => [
        if (supabaseUrl.isEmpty) 'SUPABASE_URL',
        if (supabaseKey.isEmpty) 'SUPABASE_KEY',
        if (geminiApiKey.isEmpty) 'GEMINI_API_KEY',
      ];
}