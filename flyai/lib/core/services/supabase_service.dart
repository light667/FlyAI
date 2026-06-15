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

  // Generic fetch with error handling
  static Future<List<Map<String, dynamic>>> fetchAll(
    String table, {
    String? orderBy,
    bool ascending = false,
    int? limit,
    Map<String, dynamic>? filters,
  }) async {
    var query = client.from(table).select();

    if (orderBy != null) {
      // Ordering is done at the end
    }

    final response = await client
        .from(table)
        .select()
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

  static Future<void> upsert(
    String table,
    Map<String, dynamic> data,
  ) async {
    await client.from(table).upsert(data);
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

  // Storage upload
  static Future<String?> uploadFile(
    String bucket,
    String path,
    List<int> bytes,
    String mimeType,
  ) async {
    await client.storage.from(bucket).uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(contentType: mimeType),
        );
    final url = client.storage.from(bucket).getPublicUrl(path);
    return url;
  }
}
