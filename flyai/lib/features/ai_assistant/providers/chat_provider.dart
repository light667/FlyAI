import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/ai_service.dart';
import '../../../core/services/auth_service.dart';
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

      final response = await AIService.chat(
        messages: history,
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
