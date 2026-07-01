import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/ai_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';
import '../models/chat_message_model.dart';
import '../repositories/chat_repository.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

class ChatNotifier extends StateNotifier<AsyncValue<List<ChatMessage>>> {
  final ChatRepository _repository;
  String? _sessionId;

  ChatNotifier(this._repository) : super(const AsyncData([])) {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final user = AuthService.currentUser;
    if (user == null) return;

    state = const AsyncLoading();
    try {
      final session = await _repository.getOrCreateSession(user.uid);
      if (session != null) {
        _sessionId = session;
        final history = await _repository.fetchMessages(session);
        state = AsyncData(history);
      } else {
        state = const AsyncData([]);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> sendMessage(String content) async {
    final user = AuthService.currentUser;
    if (user == null) return;

    final currentMessages = state.valueOrNull ?? [];
    
    // Create optimistic user message
    final userMsg = ChatMessage(
      id: '',
      sessionId: _sessionId ?? '',
      role: 'user',
      content: content,
      createdAt: DateTime.now(),
    );
    state = AsyncData([...currentMessages, userMsg]);

    try {
      // Create session if needed
      if (_sessionId == null) {
        _sessionId = await _repository.getOrCreateSession(user.uid);
      }

      final sessionId = _sessionId!;

      // Save user message to database
      await _repository.saveMessage(
        sessionId: sessionId,
        role: 'user',
        content: content,
      );

      // Build history for AI
      final history = [...currentMessages, userMsg]
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();

      // Retrieve RAG Context 1: Student CV PDF
      String? cvBase64;
      try {
        final profileResponse = await SupabaseService.client
            .from('profiles')
            .select('cv_url')
            .eq('firebase_uid', user.uid)
            .maybeSingle();

        if (profileResponse != null && profileResponse['cv_url'] != null) {
          final cvUrl = profileResponse['cv_url'] as String;
          final bytesResponse = await http.get(Uri.parse(cvUrl));
          if (bytesResponse.statusCode == 200) {
            cvBase64 = base64Encode(bytesResponse.bodyBytes);
          }
        }
      } catch (_) {}

      // Retrieve RAG Context 2: Top Active Scholarships in DB
      String? scholarshipsContext;
      try {
        final scholarshipsResponse = await SupabaseService.client
            .from('scholarships')
            .select()
            .eq('active', true)
            .limit(12);

        final list = (scholarshipsResponse as List)
            .map((s) => '- ${s['title']} by ${s['provider']} (Degree: ${s['degree_level']}, Fields: ${s['fields']}, Country: ${s['country']})')
            .join('\n');

        if (list.isNotEmpty) {
          scholarshipsContext = list;
        }
      } catch (_) {}

      final response = await AIService.chatWithRAG(
        messages: history,
        cvBase64: cvBase64,
        scholarshipsContext: scholarshipsContext,
        systemPrompt: AIService.scholarshipSystemPrompt,
      );

      // Save assistant message to database
      await _repository.saveMessage(
        sessionId: sessionId,
        role: 'assistant',
        content: response,
      );

      final assistantMsg = ChatMessage(
        id: '',
        sessionId: sessionId,
        role: 'assistant',
        content: response,
        createdAt: DateTime.now(),
      );

      state = AsyncData([...state.valueOrNull ?? [], assistantMsg]);
    } catch (e) {
      final errorMsg = ChatMessage(
        id: '',
        sessionId: _sessionId ?? '',
        role: 'assistant',
        content: 'Sorry, I encountered an error. Please try again. 🙏',
        createdAt: DateTime.now(),
      );
      state = AsyncData([...state.valueOrNull ?? [], errorMsg]);
    }
  }

  void clearChat() {
    state = const AsyncData([]);
    _sessionId = null;
  }
}

final chatProvider =
    StateNotifierProvider<ChatNotifier, AsyncValue<List<ChatMessage>>>((ref) {
  final repository = ref.watch(chatRepositoryProvider);
  return ChatNotifier(repository);
});
