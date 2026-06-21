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
      // Retourne null en cas d'erreur réseau ou de table manquante.
      return null;
    }
  }

  Future<void> saveProfile(ProfileModel profile) async {
    final Map<String, dynamic> json = profile.toJson();
    if (profile.id.isNotEmpty) {
      json['id'] = profile.id;
    }
    await SupabaseService.upsert(_table, json);
  }

  /// Tente d'uploader la photo de profil.
  /// Retourne l'URL publique ou null en cas d'échec (bucket inexistant, réseau…).
  Future<String?> uploadProfilePhoto(
    String firebaseUid,
    List<int> bytes,
    String fileExtension,
  ) async {
    try {
      final path = 'avatars/$firebaseUid/photo.$fileExtension';
      return await SupabaseService.uploadFile(
        'images',
        path,
        bytes,
        'image/$fileExtension',
      );
    } catch (_) {
      return null; // Upload optionnel, ne bloque pas la création du profil.
    }
  }

  /// Tente d'uploader le CV.
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
      return null; // Upload optionnel, ne bloque pas la création du profil.
    }
  }
}
