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

// ── Assistant Chat Notifier (General Assistant with RAG) ─────────────────────

class AssistantChatNotifier extends StateNotifier<AsyncValue<List<ChatMessage>>> {
  final ChatRepository _repository;
  final Ref _ref;
  String? _sessionId;

  AssistantChatNotifier(this._repository, this._ref) : super(const AsyncData([])) {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final user = AuthService.currentUser;
    if (user == null) return;
    state = const AsyncLoading();
    try {
      // Only load the MOST RECENT session if one exists; never merge sessions.
      final session = await _repository.getMostRecentSession(user.uid);
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

  Future<void> startNewChat() async {
    final user = AuthService.currentUser;
    if (user == null) return;
    state = const AsyncLoading();
    try {
      _sessionId = await _repository.createNewSession(user.uid);
      state = const AsyncData([]);
    } catch (_) {
      _sessionId = 'local_${DateTime.now().millisecondsSinceEpoch}';
      state = const AsyncData([]);
    }
  }

  Future<void> loadSession(String sessionId) async {
    state = const AsyncLoading();
    _sessionId = sessionId;
    try {
      final history = await _repository.fetchMessages(sessionId);
      state = AsyncData(history);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> sendMessage(
    String content, {
    String? attachmentName,
    String? attachmentBase64,
    String? mimeType,
  }) async {
    final user = AuthService.currentUser;
    if (user == null) return;

    final displayContent =
        attachmentName != null ? '📎 Fichier : $attachmentName\n\n$content' : content;

    final currentMessages = state.valueOrNull ?? [];
    final userMsg = ChatMessage(
      id: '',
      sessionId: _sessionId ?? '',
      role: 'user',
      content: displayContent,
      createdAt: DateTime.now(),
    );
    state = AsyncData([...currentMessages, userMsg]);

    try {
      if (_sessionId == null) {
        try {
          _sessionId = await _repository.createNewSession(user.uid);
        } catch (_) {
          _sessionId = 'local_session';
        }
      }
      final sessionId = _sessionId!;
      try {
        await _repository.saveMessage(
            sessionId: sessionId, role: 'user', content: displayContent);
      } catch (_) {}

      // General RAG Chat
      String? cvBase64 = await _fetchCvBase64(user.uid);
      String? scholarshipsContext = await _fetchScholarshipsContext();
      final response = await AIService.chatWithRAG(
        messages: [...currentMessages, userMsg]
            .map((m) => {'role': m.role, 'content': m.content})
            .toList(),
        cvBase64: cvBase64,
        scholarshipsContext: scholarshipsContext,
        systemPrompt: AIService.scholarshipSystemPrompt,
        attachedFileBase64: attachmentBase64,
        attachedFileMimeType: mimeType,
      );

      try {
        await _repository.saveMessage(
            sessionId: sessionId, role: 'assistant', content: response);
      } catch (_) {}

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
        content:
            'Une erreur s\'est produite. Veuillez réessayer. 🙏\n(Détail : $e)',
        createdAt: DateTime.now(),
      );
      state = AsyncData([...state.valueOrNull ?? [], errorMsg]);
    }
  }

  void clearChat() {
    state = const AsyncData([]);
    _sessionId = null;
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
}

// ── Coaching Chat Notifier (FlyAgent Dedicated Coach) ────────────────────────

class CoachingChatNotifier extends StateNotifier<AsyncValue<List<ChatMessage>>> {
  final ChatRepository _repository;
  final Ref _ref;
  String? _sessionId;

  CoachingChatNotifier(this._repository, this._ref) : super(const AsyncData([]));

  Future<void> startScholarshipCoaching(ScholarshipModel scholarship) async {
    final user = AuthService.currentUser;
    if (user == null) return;

    state = const AsyncData([]);
    _sessionId = null;
    _ref.read(coachingTasksProvider.notifier).clear();
    _ref.read(activeCoachingScholarshipProvider.notifier).state = scholarship;
    _ref.read(coachingPhaseProvider.notifier).state = CoachingPhase.briefing;

    // Create fresh session
    try {
      _sessionId = await _repository.createNewSession(user.uid);
    } catch (_) {
      _sessionId = 'local_coaching_${DateTime.now().millisecondsSinceEpoch}';
    }
    final sessionId = _sessionId!;

    final briefingMessage = 'START_COACHING:${scholarship.id}';
    try {
      await _repository.saveMessage(
          sessionId: sessionId, role: 'user', content: briefingMessage);
    } catch (_) {}

    state = const AsyncLoading();

    try {
      final profileJson = await SupabaseService.fetchOne(
          'profiles', 'firebase_uid', user.uid);
      final scholarshipsContext = await _fetchScholarshipsContext();

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
        id: '',
        sessionId: sessionId,
        role: 'assistant',
        content: displayContent,
        createdAt: DateTime.now(),
      );

      state = AsyncData([briefingMsg]);
      _ref.read(coachingPhaseProvider.notifier).state =
          CoachingPhase.awaitingConfirmation;
    } catch (e) {
      debugPrint('[CoachingChatNotifier] error: $e');
      final fallback = _buildFallbackBriefing(scholarship);
      final msg = ChatMessage(
        id: '',
        sessionId: sessionId,
        role: 'assistant',
        content: fallback,
        createdAt: DateTime.now(),
      );
      state = AsyncData([msg]);
      _ref.read(coachingPhaseProvider.notifier).state =
          CoachingPhase.awaitingConfirmation;
    }
  }

  Future<void> sendMessage(String content) async {
    final user = AuthService.currentUser;
    final scholarship = _ref.read(activeCoachingScholarshipProvider);
    if (user == null || scholarship == null) return;

    final currentMessages = state.valueOrNull ?? [];
    final userMsg = ChatMessage(
      id: '',
      sessionId: _sessionId ?? '',
      role: 'user',
      content: content,
      createdAt: DateTime.now(),
    );
    state = AsyncData([...currentMessages, userMsg]);

    try {
      if (_sessionId == null) {
        try {
          _sessionId = await _repository.createNewSession(user.uid);
        } catch (_) {
          _sessionId = 'local_coaching';
        }
      }
      final sessionId = _sessionId!;
      try {
        await _repository.saveMessage(
            sessionId: sessionId, role: 'user', content: content);
      } catch (_) {}

      // Detect confirmation phase switch
      final lower = content.toLowerCase();
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
          'profiles', 'firebase_uid', user.uid);
      final scholarshipsContext = await _fetchScholarshipsContext();

      final response = await AIService.callCoachingAgent(
        scholarship: scholarship,
        profileJson: profileJson,
        messages: [...currentMessages, userMsg]
            .map((m) => {'role': m.role, 'content': m.content})
            .toList(),
        scholarshipsContext: scholarshipsContext,
        generateTasks: phase == CoachingPhase.coaching &&
            _ref.read(coachingTasksProvider).isEmpty,
      );

      try {
        await _repository.saveMessage(
            sessionId: sessionId, role: 'assistant', content: response);
      } catch (_) {}

      _extractTasks(response);

      final displayContent = CoachingTask.stripTasksBlock(response);
      final assistantMsg = ChatMessage(
        id: '',
        sessionId: sessionId,
        role: 'assistant',
        content: displayContent,
        createdAt: DateTime.now(),
      );
      state = AsyncData([...state.valueOrNull ?? [], assistantMsg]);
    } catch (e) {
      final errorMsg = ChatMessage(
        id: '',
        sessionId: _sessionId ?? '',
        role: 'assistant',
        content:
            'Une erreur s\'est produite. Veuillez réessayer. 🙏\n(Détail : $e)',
        createdAt: DateTime.now(),
      );
      state = AsyncData([...state.valueOrNull ?? [], errorMsg]);
    }
  }

  void _extractTasks(String response) {
    final tasks = CoachingTask.parseFromAiResponse(response);
    if (tasks.isNotEmpty) {
      _ref.read(coachingTasksProvider.notifier).setTasks(tasks);
      _ref.read(coachingPhaseProvider.notifier).state = CoachingPhase.coaching;
    }
  }

  void clearChat() {
    state = const AsyncData([]);
    _sessionId = null;
    _ref.read(activeCoachingScholarshipProvider.notifier).state = null;
    _ref.read(coachingTasksProvider.notifier).clear();
    _ref.read(coachingPhaseProvider.notifier).state = CoachingPhase.idle;
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
${scholarship.description.isNotEmpty ? scholarship.description : 'Bourse internationale.'}

---

Es-tu prêt(e) à commencer ? Réponds **Oui** pour que je crée ton plan d'action personnalisé.
''';
  }
}

// ── Providers ──────────────────────────────────────────────────────────────

final assistantChatProvider =
    StateNotifierProvider<AssistantChatNotifier, AsyncValue<List<ChatMessage>>>((ref) {
  final repository = ref.watch(chatRepositoryProvider);
  return AssistantChatNotifier(repository, ref);
});

final coachingChatProvider =
    StateNotifierProvider<CoachingChatNotifier, AsyncValue<List<ChatMessage>>>((ref) {
  final repository = ref.watch(chatRepositoryProvider);
  return CoachingChatNotifier(repository, ref);
});
