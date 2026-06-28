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

    // Inclure l'id uniquement s'il existe déjà (update), sinon Supabase le génère.
    if (profile.id.isNotEmpty) {
      json['id'] = profile.id;
    }

    // onConflict: 'firebase_uid' est indispensable ici.
    // Sans lui, Supabase tente un INSERT et échoue avec 409/400 si
    // firebase_uid est déjà présent (contrainte UNIQUE sur le schéma).
    await SupabaseService.upsertWithConflict(
      _table,
      json,
      onConflict: 'firebase_uid',
    );
  }

  /// Tente d'uploader la photo de profil dans le bucket 'documents' (sous-dossier photos/).
  /// Le bucket 'images' n'est pas configuré — on réutilise 'documents' qui fonctionne.
  /// Retourne l'URL publique ou null en cas d'échec.
  Future<String?> uploadProfilePhoto(
    String firebaseUid,
    List<int> bytes,
    String fileExtension,
  ) async {
    try {
      final path = 'photos/$firebaseUid/photo.$fileExtension';
      return await SupabaseService.uploadFile(
        'documents',
        path,
        bytes,
        'image/$fileExtension',
      );
    } catch (e) {
      // ignore: avoid_print
      print('[ProfileRepository] uploadProfilePhoto error: $e');
      return null;
    }
  }

  /// Tente d'uploader le CV dans le bucket 'documents'.
  /// Retourne l'URL publique ou null en cas d'échec.
  Future<String?> uploadCV(
    String firebaseUid,
    List<int> bytes,
    String fileExtension,
  ) async {
    try {
      final path = 'cvs/$firebaseUid/cv.$fileExtension';
      return await SupabaseService.uploadFile(
        'documents',
        path,
        bytes,
        fileExtension == 'pdf'
            ? 'application/pdf'
            : 'application/octet-stream',
      );
    } catch (_) {
      return null;
    }
  }
}