import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../core/services/ai_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';
import '../models/chat_message_model.dart';
import '../repositories/chat_repository.dart';
import '../../scholarships/models/scholarship_model.dart';
import '../providers/scholarship_coaching_provider.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

class ChatNotifier extends StateNotifier<AsyncValue<List<ChatMessage>>> {
  final ChatRepository _repository;
  final Ref _ref;
  String? _sessionId;

  ChatNotifier(this._repository, this._ref) : super(const AsyncData([])) {
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

  // ── Standard message ───────────────────────────────────────────────────────

  Future<void> sendMessage(String content) async {
    final user = AuthService.currentUser;
    if (user == null) return;

    final currentMessages = state.valueOrNull ?? [];
    final userMsg = ChatMessage(
      id: '', sessionId: _sessionId ?? '', role: 'user',
      content: content, createdAt: DateTime.now(),
    );
    state = AsyncData([...currentMessages, userMsg]);

    try {
      if (_sessionId == null) {
        try {
          _sessionId = await _repository.getOrCreateSession(user.uid);
        } catch (_) {
          _sessionId = 'local_session';
        }
      }
      final sessionId = _sessionId!;
      try {
        await _repository.saveMessage(sessionId: sessionId, role: 'user', content: content);
      } catch (_) {}

      // Check if we are in coaching mode
      final scholarship = _ref.read(activeCoachingScholarshipProvider);
      String response;
      if (scholarship != null) {
        response = await _getCoachingResponse(
          userMessage: content,
          scholarship: scholarship,
          history: [...currentMessages, userMsg],
        );
      } else {
        // Standard RAG chat
        String? cvBase64 = await _fetchCvBase64(user.uid);
        String? scholarshipsContext = await _fetchScholarshipsContext();
        response = await AIService.chatWithRAG(
          messages: [...currentMessages, userMsg]
              .map((m) => {'role': m.role, 'content': m.content})
              .toList(),
          cvBase64: cvBase64,
          scholarshipsContext: scholarshipsContext,
          systemPrompt: AIService.scholarshipSystemPrompt,
        );
      }

      try {
        await _repository.saveMessage(sessionId: sessionId, role: 'assistant', content: response);
      } catch (_) {}

      // Extract tasks if any
      _extractTasks(response);

      final displayContent = CoachingTask.stripTasksBlock(response);
      final assistantMsg = ChatMessage(
        id: '', sessionId: sessionId, role: 'assistant',
        content: displayContent, createdAt: DateTime.now(),
      );
      state = AsyncData([...state.valueOrNull ?? [], assistantMsg]);
    } catch (e) {
      final errorMsg = ChatMessage(
        id: '', sessionId: _sessionId ?? '', role: 'assistant',
        content: 'Une erreur s\'est produite. Veuillez réessayer. 🙏\n(Détail : $e)',
        createdAt: DateTime.now(),
      );
      state = AsyncData([...state.valueOrNull ?? [], errorMsg]);
    }
  }

  // ── Scholarship coaching entry point ───────────────────────────────────────

  Future<void> startScholarshipCoaching(ScholarshipModel scholarship) async {
    final user = AuthService.currentUser;
    if (user == null) return;

    // Reset state
    state = const AsyncData([]);
    _sessionId = null;
    _ref.read(coachingTasksProvider.notifier).clear();
    _ref.read(activeCoachingScholarshipProvider.notifier).state = scholarship;
    _ref.read(coachingPhaseProvider.notifier).state = CoachingPhase.briefing;

    // Create fresh session
    try {
      _sessionId = await _repository.getOrCreateSession(user.uid);
    } catch (_) {
      _sessionId = 'local_session';
    }
    final sessionId = _sessionId!;

    // Build the initial briefing prompt
    final briefingMessage = _buildBriefingPrompt(scholarship);

    // Save the user action in history (internal, not displayed)
    try {
      await _repository.saveMessage(
        sessionId: sessionId,
        role: 'user',
        content: briefingMessage,
      );
    } catch (_) {}

    state = const AsyncLoading();

    try {
      // Fetch student profile for personalization
      final profileJson = await SupabaseService.fetchOne(
          'profiles', 'firebase_uid', user.uid);

      // Get scholarships context
      final scholarshipsContext = await _fetchScholarshipsContext();

      // Call the coaching agent
      final response = await AIService.callCoachingAgent(
        scholarship: scholarship,
        profileJson: profileJson,
        messages: [{'role': 'user', 'content': briefingMessage}],
        scholarshipsContext: scholarshipsContext,
      );

      try {
        await _repository.saveMessage(
            sessionId: sessionId, role: 'assistant', content: response);
      } catch (_) {}

      _extractTasks(response);

      final displayContent = CoachingTask.stripTasksBlock(response);
      final briefingMsg = ChatMessage(
        id: '', sessionId: sessionId, role: 'assistant',
        content: displayContent, createdAt: DateTime.now(),
      );

      state = AsyncData([briefingMsg]);
      _ref.read(coachingPhaseProvider.notifier).state =
          CoachingPhase.awaitingConfirmation;
    } catch (e) {
      debugPrint('[ChatNotifier] startScholarshipCoaching error: $e');
      final fallback = _buildFallbackBriefing(scholarship);
      final msg = ChatMessage(
        id: '', sessionId: sessionId, role: 'assistant',
        content: fallback, createdAt: DateTime.now(),
      );
      state = AsyncData([msg]);
      _ref.read(coachingPhaseProvider.notifier).state =
          CoachingPhase.awaitingConfirmation;
    }
  }

  // ── Coaching response ──────────────────────────────────────────────────────

  Future<String> _getCoachingResponse({
    required String userMessage,
    required ScholarshipModel scholarship,
    required List<ChatMessage> history,
  }) async {
    // Detect if user confirmed → switch to full coaching phase
    final lower = userMessage.toLowerCase();
    final isConfirmation = lower.contains('oui') ||
        lower.contains('yes') ||
        lower.contains('d\'accord') ||
        lower.contains('ok') ||
        lower.contains('continuer') ||
        lower.contains('continue') ||
        lower.contains('commencer') ||
        lower.contains('start') ||
        lower.contains('let\'s');

    if (isConfirmation &&
        _ref.read(coachingPhaseProvider) ==
            CoachingPhase.awaitingConfirmation) {
      _ref.read(coachingPhaseProvider.notifier).state = CoachingPhase.coaching;
    }

    final phase = _ref.read(coachingPhaseProvider);
    final profileJson = await SupabaseService.fetchOne(
        'profiles', 'firebase_uid', AuthService.currentUser!.uid);
    final scholarshipsContext = await _fetchScholarshipsContext();

    return AIService.callCoachingAgent(
      scholarship: scholarship,
      profileJson: profileJson,
      messages: history.map((m) => {'role': m.role, 'content': m.content}).toList(),
      scholarshipsContext: scholarshipsContext,
      generateTasks: phase == CoachingPhase.coaching &&
          _ref.read(coachingTasksProvider).isEmpty,
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _buildBriefingPrompt(ScholarshipModel scholarship) {
    return 'START_COACHING:${scholarship.id}';
  }

  String _buildFallbackBriefing(ScholarshipModel scholarship) {
    final dl = scholarship.deadline != null
        ? '📅 Deadline : ${scholarship.deadline!.day}/${scholarship.deadline!.month}/${scholarship.deadline!.year}'
        : '';
    return '''
🎓 **${scholarship.title}**

📍 **Pays** : ${scholarship.country}
🏛️ **Université** : ${scholarship.university}
💰 **Financement** : ${scholarship.fundingType}
📚 **Niveau** : ${scholarship.degreeLevel}
$dl

**Description** :
${scholarship.description.isNotEmpty ? scholarship.description : 'Bourse internationale pour étudiants méritants.'}

---

J'ai analysé cette bourse pour toi. Es-tu prêt(e) à commencer le processus de candidature ? Réponds **Oui** pour que je crée ton plan d'action personnalisé.
''';
  }

  void _extractTasks(String response) {
    final tasks = CoachingTask.parseFromAiResponse(response);
    if (tasks.isNotEmpty) {
      _ref.read(coachingTasksProvider.notifier).setTasks(tasks);
      _ref.read(coachingPhaseProvider.notifier).state = CoachingPhase.coaching;
    }
  }

  Future<String?> _fetchCvBase64(String uid) async {
    try {
      final profileResponse = await SupabaseService.client
          .from('profiles')
          .select('cv_url')
          .eq('firebase_uid', uid)
          .maybeSingle();
      if (profileResponse?['cv_url'] != null) {
        final r = await http.get(Uri.parse(profileResponse!['cv_url'] as String));
        if (r.statusCode == 200) return base64Encode(r.bodyBytes);
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _fetchScholarshipsContext() async {
    try {
      final res = await SupabaseService.client
          .from('scholarships')
          .select()
          .eq('active', true)
          .limit(15);
      final list = (res as List)
          .map((s) =>
              '- ${s['title']} | ${s['provider']} | ${s['country']} | ${s['degree_level']}')
          .join('\n');
      return list.isNotEmpty ? list : null;
    } catch (_) {
      return null;
    }
  }

  void clearChat() {
    state = const AsyncData([]);
    _sessionId = null;
    _ref.read(activeCoachingScholarshipProvider.notifier).state = null;
    _ref.read(coachingTasksProvider.notifier).clear();
    _ref.read(coachingPhaseProvider.notifier).state = CoachingPhase.idle;
  }

  /// Load a specific session from history by its ID
  Future<void> loadSession(String sessionId) async {
    state = const AsyncLoading();
    _sessionId = sessionId;
    // Clear coaching state when loading an old session
    _ref.read(activeCoachingScholarshipProvider.notifier).state = null;
    _ref.read(coachingTasksProvider.notifier).clear();
    _ref.read(coachingPhaseProvider.notifier).state = CoachingPhase.idle;
    try {
      final history = await _repository.fetchMessages(sessionId);
      state = AsyncData(history);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final chatProvider =
    StateNotifierProvider<ChatNotifier, AsyncValue<List<ChatMessage>>>((ref) {
  final repository = ref.watch(chatRepositoryProvider);
  return ChatNotifier(repository, ref);
});
