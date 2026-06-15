import '../../../core/services/supabase_service.dart';
import '../models/profile_model.dart';

class ProfileRepository {
  static const _table = 'profiles';

  Future<ProfileModel?> getProfile(String firebaseUid) async {
    try {
      final data = await SupabaseService.fetchOne(_table, 'firebase_uid', firebaseUid);
      if (data == null) return null;
      return ProfileModel.fromJson(data);
    } catch (e) {
      // Return null on error (e.g. table doesn't exist yet, or network failure)
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

  Future<String?> uploadProfilePhoto(String firebaseUid, List<int> bytes, String fileExtension) async {
    final path = 'avatars/$firebaseUid/photo.$fileExtension';
    // images bucket
    return SupabaseService.uploadFile(
      'images',
      path,
      bytes,
      'image/$fileExtension',
    );
  }

  Future<String?> uploadCV(String firebaseUid, List<int> bytes, String fileExtension) async {
    final path = 'cvs/$firebaseUid/cv.$fileExtension';
    // documents bucket
    return SupabaseService.uploadFile(
      'documents',
      path,
      bytes,
      fileExtension == 'pdf' ? 'application/pdf' : 'application/octet-stream',
    );
  }
}
