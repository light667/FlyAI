import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseService {
  SupabaseService._();

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await dotenv.load(fileName: '.env');

    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_KEY']!,
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
    // Build query with filters applied before ordering/limiting.
    // filters are applied via .eq() chaining on the PostgrestFilterBuilder.
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

  /// Upsert basique (conflit sur la clé primaire).
  static Future<void> upsert(
    String table,
    Map<String, dynamic> data,
  ) async {
    await client.from(table).upsert(data);
  }

  /// Upsert avec résolution de conflit sur une colonne spécifique.
  /// Utiliser pour les tables avec UNIQUE contrainte (ex: firebase_uid).
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

  /// Upload un fichier binaire vers un bucket Supabase Storage.
  /// [upsert: true] permet d'écraser un fichier existant au même chemin
  /// sans renvoyer d'erreur 400 (conflict).
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
            upsert: true, // ← Evite les erreurs 400 sur re-upload
          ),
        );
    final url = client.storage.from(bucket).getPublicUrl(path);
    return url;
  }
}