import '../../../core/services/supabase_service.dart';
import '../models/profile_model.dart';

class ProfileRepository {
  static const _table = 'profiles';

  Future<ProfileModel?> getProfile(String firebaseUid) async {
    try {
      final data =
          await SupabaseService.fetchOne(_table, 'firebase_uid', firebaseUid);
      if (data == null) return null;
      return ProfileModel.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveProfile(ProfileModel profile) async {
    final Map<String, dynamic> json = profile.toJson();
    if (profile.id.isNotEmpty) {
      json['id'] = profile.id;
    }
    await SupabaseService.upsertWithConflict(
      _table,
      json,
      onConflict: 'firebase_uid',
    );
  }

  // ── Photo upload ──────────────────────────────────────────────────────────

  /// Upload la photo de profil dans le bucket 'documents' (dossier photos/).
  ///
  /// Root cause de l'erreur "Invalid media type: expected no more input" :
  /// Sur Flutter Web, [XFile.path] renvoie une blob URL complète, par ex.
  ///   "blob:http://localhost:50214/0d7ef3fe-3c55-4b19-96f4-74843a176c30"
  /// au lieu d'une extension simple comme "jpg".
  /// Ce blob URL était passé verbatim dans 'image/$fileExtension', produisant
  /// 'image/blob:http://...' → rejeté immédiatement par Supabase Storage.
  ///
  /// Fix : [_sanitizeExtension] extrait l'extension réelle ou retourne 'jpg'.
  Future<String?> uploadProfilePhoto(
    String firebaseUid,
    List<int> bytes,
    String fileExtension,
  ) async {
    try {
      final ext = _sanitizeExtension(fileExtension, fallback: 'jpg');
      final path = 'photos/$firebaseUid/photo.$ext';
      return await SupabaseService.uploadFile(
        'documents',
        path,
        bytes,
        'image/$ext',
      );
    } catch (e) {
      // ignore: avoid_print
      print('[ProfileRepository] uploadProfilePhoto error: $e');
      return null;
    }
  }

  // ── CV upload ─────────────────────────────────────────────────────────────

  /// Upload le CV dans le bucket 'documents' (dossier cvs/).
  /// Même sanitisation de l'extension que pour la photo.
  Future<String?> uploadCV(
    String firebaseUid,
    List<int> bytes,
    String fileExtension,
  ) async {
    try {
      final ext = _sanitizeExtension(fileExtension, fallback: 'pdf');
      final path = 'cvs/$firebaseUid/cv.$ext';
      final mimeType = ext == 'pdf' ? 'application/pdf' : 'application/octet-stream';
      return await SupabaseService.uploadFile('documents', path, bytes, mimeType);
    } catch (e) {
      // ignore: avoid_print
      print('[ProfileRepository] uploadCV error: $e');
      return null;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Extrait une extension de fichier utilisable depuis [raw].
  ///
  /// Cas gérés :
  ///   "jpg"                                         → "jpg"   (déjà valide)
  ///   "photo.jpg"                                   → "jpg"
  ///   "/tmp/upload/photo.png"                       → "png"
  ///   "blob:http://localhost:50214/uuid"             → [fallback]
  ///   "blob:http://localhost:50214/uuid.jpg"         → "jpg"  (rare mais possible)
  ///   ""  /  null-like                              → [fallback]
  String _sanitizeExtension(String raw, {required String fallback}) {
    // Cas simple : extension courte sans caractères spéciaux (1-5 alphanum)
    if (RegExp(r'^[a-zA-Z0-9]{1,5}$').hasMatch(raw)) {
      return raw.toLowerCase();
    }

    // Tentative d'extraction depuis un chemin/URL :
    // On prend le dernier segment après '.', en ignorant les query strings.
    final lastDot = raw.lastIndexOf('.');
    if (lastDot != -1 && lastDot < raw.length - 1) {
      final candidate = raw
          .substring(lastDot + 1)
          .split('?')
          .first
          .split('#')
          .first
          .toLowerCase();

      if (RegExp(r'^[a-zA-Z0-9]{1,5}$').hasMatch(candidate)) {
        return candidate;
      }
    }

    // Blob URL ou autre format non parseable → retomber sur le fallback.
    return fallback;
  }
}