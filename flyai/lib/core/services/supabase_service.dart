import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

class SupabaseService {
  SupabaseService._();

  static SupabaseClient get client => Supabase.instance.client;

  /// Initialise Supabase depuis les constantes compilées (AppConfig).
  /// Aucun chargement de fichier .env au runtime.
  static Future<void> initialize() async {
    assert(
      AppConfig.supabaseUrl.isNotEmpty && AppConfig.supabaseKey.isNotEmpty,
      '\n\n[SupabaseService] Clés manquantes !\n'
      'Lance l\'app avec :\n'
      '  flutter run --dart-define-from-file=dart_defines.json\n'
      'ou pour le build web :\n'
      '  flutter build web --dart-define-from-file=dart_defines.json\n',
    );

    if (kDebugMode && AppConfig.missingKeys.isNotEmpty) {
      // ignore: avoid_print
      print('[AppConfig] Clés manquantes : ${AppConfig.missingKeys}');
    }

    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseKey,
    );
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
          fileOptions: FileOptions(contentType: mimeType, upsert: true),
        );
    return client.storage.from(bucket).getPublicUrl(path);
  }
}