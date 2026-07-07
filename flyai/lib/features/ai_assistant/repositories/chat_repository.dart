import '../../../core/services/supabase_service.dart';
import '../models/chat_message_model.dart';

class ChatRepository {
  Future<String?> getOrCreateSession(String firebaseUid) async {
    final sessions = await SupabaseService.client
        .from('chat_sessions')
        .select()
        .eq('firebase_uid', firebaseUid)
        .order('created_at', ascending: false)
        .limit(1);

    if ((sessions as List).isNotEmpty) {
      return sessions[0]['id'] as String;
    }

    return createNewSession(firebaseUid);
  }

  Future<String> createNewSession(String firebaseUid) async {
    final res = await SupabaseService.client
        .from('chat_sessions')
        .insert({'firebase_uid': firebaseUid})
        .select()
        .single();
    return res['id'] as String;
  }

  Future<List<ChatMessage>> fetchMessages(String sessionId) async {
    final msgs = await SupabaseService.client
        .from('chat_messages')
        .select()
        .eq('session_id', sessionId)
        .order('created_at');

    return (msgs as List)
        .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveMessage({
    required String sessionId,
    required String role,
    required String content,
  }) async {
    await SupabaseService.client.from('chat_messages').insert({
      'session_id': sessionId,
      'role': role,
      'content': content,
    });
  }
}
