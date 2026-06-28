import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

class SupabaseService {
  SupabaseService._();

  static SupabaseClient get client => Supabase.instance.client;

  /// Initialise Supabase.
  ///
  /// En local : charge `assets/.env` via dotenv → lit SUPABASE_URL / KEY.
  /// En production (Firebase Hosting) : le `.env` n'existe pas (404).
  ///   → le try/catch absorbe l'erreur sans crasher le splash screen.
  ///   → [AppConfig] lit les constantes compilées via --dart-define-from-file.
  static Future<void> initialize() async {
    // Tentative de chargement du .env (développement local uniquement).
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // Silencieux en production — les valeurs viennent de AppConfig.
      if (kDebugMode) {
        // ignore: avoid_print
        print('[SupabaseService] .env introuvable — '
            'utilisation des constantes compilées (AppConfig).');
      }
    }

    final url = AppConfig.supabaseUrl;
    final key = AppConfig.supabaseKey;

    assert(
      url.isNotEmpty && key.isNotEmpty,
      '[SupabaseService] SUPABASE_URL / SUPABASE_KEY manquants.\n'
      'Local : vérifiez assets/.env\n'
      'Production : flutter build web --dart-define-from-file=dart_defines.json',
    );

    await Supabase.initialize(url: url, anonKey: key);
  }

  // ── Generic fetch ─────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> fetchAll(
    String table, {
    String? orderBy,
    bool ascending = false,
    int? limit,
    Map<String, dynamic>? filters,
  }) async {
    var query = client.from(table).select();

    if (filters != null) {
      for (final entry in filters.entries) {
        query = query.eq(entry.key, entry.value);
      }
    }

    final response = await query
        .order(orderBy ?? 'created_at', ascending: ascending)
        .limit(limit ?? 50);

    return List<Map<String, dynamic>>.from(response);
  }

  static Future<Map<String, dynamic>?> fetchOne(
    String table,
    String column,
    String value,
  ) async {
    final response = await client
        .from(table)
        .select()
        .eq(column, value)
        .maybeSingle();
    return response;
  }

  // ── Write operations ──────────────────────────────────────────────────────

  static Future<void> upsert(
    String table,
    Map<String, dynamic> data,
  ) async {
    await client.from(table).upsert(data);
  }

  static Future<void> upsertWithConflict(
    String table,
    Map<String, dynamic> data, {
    required String onConflict,
  }) async {
    await client.from(table).upsert(data, onConflict: onConflict);
  }

  static Future<void> insert(
    String table,
    Map<String, dynamic> data,
  ) async {
    await client.from(table).insert(data);
  }

  static Future<void> update(
    String table,
    Map<String, dynamic> data,
    String column,
    String value,
  ) async {
    await client.from(table).update(data).eq(column, value);
  }

  static Future<void> delete(
    String table,
    String column,
    String value,
  ) async {
    await client.from(table).delete().eq(column, value);
  }

  // ── Storage ───────────────────────────────────────────────────────────────

  static Future<String?> uploadFile(
    String bucket,
    String path,
    List<int> bytes,
    String mimeType,
  ) async {
    await client.storage.from(bucket).uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(
            contentType: mimeType,
            upsert: true,
          ),
        );
    return client.storage.from(bucket).getPublicUrl(path);
  }
}