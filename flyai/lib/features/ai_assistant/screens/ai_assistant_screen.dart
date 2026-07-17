import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';
import '../models/chat_message_model.dart';
import '../providers/chat_provider.dart';
import '../providers/scholarship_coaching_provider.dart';

// ── Chat session model for history panel ────────────────────────────────────
class ChatSessionItem {
  final String id;
  final String title;
  final DateTime createdAt;
  ChatSessionItem({required this.id, required this.title, required this.createdAt});
}

// ── Attached file model ──────────────────────────────────────────────────────
class _AttachedFile {
  final String name;
  final String mimeType;
  final Uint8List bytes;
  _AttachedFile({required this.name, required this.mimeType, required this.bytes});
}

// ── AI tab index provider ────────────────────────────────────────────────────
final _aiTabProvider = StateProvider<int>((ref) => 0); // 0 = Assistant, 1 = Agent

// ─────────────────────────────────────────────────────────────────────────────
// Main Screen
// ─────────────────────────────────────────────────────────────────────────────

class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});
  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = ref.read(pendingCoachingScholarshipProvider);
      if (pending != null) {
        // Auto-switch to Agent tab when a scholarship is pending
        ref.read(_aiTabProvider.notifier).state = 1;
        ref.read(pendingCoachingScholarshipProvider.notifier).state = null;
        ref.read(coachingChatProvider.notifier).startScholarshipCoaching(pending);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tabIndex = ref.watch(_aiTabProvider);

    // React to scholarship pending even while screen is open
    ref.listen(pendingCoachingScholarshipProvider, (_, scholarship) {
      if (scholarship != null) {
        ref.read(_aiTabProvider.notifier).state = 1;
        ref.read(pendingCoachingScholarshipProvider.notifier).state = null;
        ref.read(coachingChatProvider.notifier).startScholarshipCoaching(scholarship);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Tab Header ──────────────────────────────────────────────────
          _AiTabHeader(
            tabIndex: tabIndex,
            onTabChanged: (i) => ref.read(_aiTabProvider.notifier).state = i,
          ),

          // ── Tab Content ─────────────────────────────────────────────────
          Expanded(
            child: IndexedStack(
              index: tabIndex,
              children: const [
                _AssistantTab(),
                _AgentTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab Header
// ─────────────────────────────────────────────────────────────────────────────

class _AiTabHeader extends StatelessWidget {
  final int tabIndex;
  final void Function(int) onTabChanged;
  const _AiTabHeader({required this.tabIndex, required this.onTabChanged});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border(bottom: BorderSide(color: AppColors.glassBorder, width: 1)),
        ),
        child: Column(
          children: [
            // Logo row
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppColors.primary, Color(0xFF7C3AED)],
                    ),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, size: 18, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Text('Fly AI',
                    style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w800)),
                const Spacer(),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text('Actif', style: AppTextStyles.caption.copyWith(color: AppColors.success)),
              ],
            ),
            const SizedBox(height: 12),

            // Tab switcher
            Row(
              children: [
                Expanded(child: _TabChip(label: '💬 FlyAssistant', active: tabIndex == 0, onTap: () => onTabChanged(0))),
                const SizedBox(width: 10),
                Expanded(child: _TabChip(label: '🎯 FlyAgent', active: tabIndex == 1, onTap: () => onTabChanged(1))),
              ],
            ),
            const SizedBox(height: 2),
          ],
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(colors: [AppColors.primary, Color(0xFF7C3AED)])
              : null,
          color: active ? null : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.glassBorder,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : AppColors.textSecondary,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FlyAssistant Tab (General AI with file upload + session history)
// ─────────────────────────────────────────────────────────────────────────────

class _AssistantTab extends ConsumerStatefulWidget {
  const _AssistantTab();
  @override
  ConsumerState<_AssistantTab> createState() => _AssistantTabState();
}

class _AssistantTabState extends ConsumerState<_AssistantTab> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isSending = false;
  bool _showHistory = false;
  List<ChatSessionItem> _sessions = [];
  bool _sessionsLoading = false;
  _AttachedFile? _attachedFile;

  final _quickActions = [
    ('Évalue mon CV', Icons.description_outlined, 'Peux-tu analyser mon CV et me suggérer des améliorations ?'),
    ('Rédige ma lettre de motivation', Icons.edit_note_rounded, 'Rédige une lettre de motivation complète pour cette bourse.'),
    ('Préparation entretien', Icons.mic_none_rounded, 'Aide-moi à préparer mon entretien de sélection.'),
    ('Stratégie de candidature', Icons.route_outlined, 'Quelle stratégie adopter pour maximiser mes chances ?'),
    ('SOP complet', Icons.article_outlined, 'Rédige mon Statement of Purpose complet pour cette bourse.'),
  ];

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send([String? text]) async {
    final content = (text ?? _msgCtrl.text).trim();
    if (content.isEmpty || _isSending) return;

    String? base64Data;
    String? mimeType;
    String? fileName;

    if (_attachedFile != null) {
      base64Data = base64Encode(_attachedFile!.bytes);
      mimeType = _attachedFile!.mimeType;
      fileName = _attachedFile!.name;
    }

    setState(() {
      _isSending = true;
      _attachedFile = null; // clear after send
    });
    _msgCtrl.clear();

    await ref.read(assistantChatProvider.notifier).sendMessage(
          content,
          attachmentName: fileName,
          attachmentBase64: base64Data,
          mimeType: mimeType,
        );

    setState(() => _isSending = false);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
      withData: true, // Required for Flutter Web (bytes-based)
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    String mimeType = 'application/octet-stream';
    final ext = (file.extension ?? '').toLowerCase();
    if (ext == 'pdf') mimeType = 'application/pdf';
    else if (ext == 'txt') mimeType = 'text/plain';
    else if (ext == 'jpg' || ext == 'jpeg') mimeType = 'image/jpeg';
    else if (ext == 'png') mimeType = 'image/png';
    else if (ext == 'doc' || ext == 'docx') mimeType = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

    setState(() {
      _attachedFile = _AttachedFile(
        name: file.name,
        mimeType: mimeType,
        bytes: file.bytes!,
      );
    });
  }

  Future<void> _loadSessions() async {
    final user = AuthService.currentUser;
    if (user == null) return;
    setState(() => _sessionsLoading = true);
    try {
      final rows = await SupabaseService.client
          .from('chat_sessions')
          .select('id, created_at')
          .eq('firebase_uid', user.uid)
          .order('created_at', ascending: false)
          .limit(30);

      final items = (rows as List).map((r) {
        final dt = DateTime.tryParse(r['created_at'] as String? ?? '') ?? DateTime.now();
        final months = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun', 'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];
        final label = '${dt.day} ${months[dt.month - 1]} — ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        return ChatSessionItem(id: r['id'] as String, title: label, createdAt: dt);
      }).toList();

      if (mounted) setState(() { _sessions = items; _sessionsLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _sessionsLoading = false);
    }
  }

  Future<void> _loadSession(String sessionId) async {
    await ref.read(assistantChatProvider.notifier).loadSession(sessionId);
    if (mounted) setState(() => _showHistory = false);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(assistantChatProvider);
    final messages = messagesAsync.valueOrNull ?? [];
    final isLoading = messagesAsync is AsyncLoading;
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final inputPadding = keyboardOpen ? 12.0 : bottomInset + 66.0 + 12.0;

    ref.listen(assistantChatProvider, (_, next) {
      if (next.valueOrNull?.isNotEmpty == true) _scrollToBottom();
    });

    return Column(
      children: [
        // ── Toolbar: History + New Chat ────────────────────────────────
        _AssistantToolbar(
          showHistory: _showHistory,
          onToggleHistory: () {
            setState(() => _showHistory = !_showHistory);
            if (_showHistory) _loadSessions();
          },
          onNewChat: () {
            ref.read(assistantChatProvider.notifier).startNewChat();
            setState(() { _showHistory = false; _attachedFile = null; });
          },
        ),

        // ── History Panel ──────────────────────────────────────────────
        if (_showHistory)
          Expanded(
            child: _HistoryPanel(
              sessions: _sessions,
              isLoading: _sessionsLoading,
              onSelect: _loadSession,
              onClose: () => setState(() => _showHistory = false),
              onNewChat: () {
                ref.read(assistantChatProvider.notifier).startNewChat();
                setState(() { _showHistory = false; _attachedFile = null; });
              },
            ),
          )
        else ...[
          // ── Messages ────────────────────────────────────────────────
          Expanded(
            child: isLoading && messages.isEmpty
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : messages.isEmpty
                    ? _AssistantWelcome(quickActions: _quickActions, onTap: _send)
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        itemCount: messages.length + (_isSending ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i == messages.length && _isSending) return const _TypingBubble();
                          final msg = messages[i];
                          return _MessageBubble(role: msg.role, content: msg.content);
                        },
                      ),
          ),

          // ── File attachment preview ──────────────────────────────────
          if (_attachedFile != null)
            _FilePreviewBar(
              file: _attachedFile!,
              onRemove: () => setState(() => _attachedFile = null),
            ),

          // ── Input bar ────────────────────────────────────────────────
          _InputBar(
            controller: _msgCtrl,
            isSending: _isSending,
            onSend: _send,
            onChanged: () => setState(() {}),
            onAttach: _pickFile,
            hint: "Pose-moi n'importe quelle question…",
            extraBottomPadding: inputPadding,
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FlyAgent Tab (Coaching mode)
// ─────────────────────────────────────────────────────────────────────────────

class _AgentTab extends ConsumerStatefulWidget {
  const _AgentTab();
  @override
  ConsumerState<_AgentTab> createState() => _AgentTabState();
}

class _AgentTabState extends ConsumerState<_AgentTab> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isSending = false;
  bool _taskPanelExpanded = true;

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send([String? text]) async {
    final content = (text ?? _msgCtrl.text).trim();
    if (content.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    _msgCtrl.clear();
    await ref.read(coachingChatProvider.notifier).sendMessage(content);
    setState(() => _isSending = false);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(coachingChatProvider);
    final messages = messagesAsync.valueOrNull ?? [];
    final tasks = ref.watch(coachingTasksProvider);
    final phase = ref.watch(coachingPhaseProvider);
    final activeScholarship = ref.watch(activeCoachingScholarshipProvider);
    final isCoaching = activeScholarship != null;
    final isLoading = messagesAsync is AsyncLoading;
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final inputPadding = keyboardOpen ? 12.0 : bottomInset + 66.0 + 12.0;

    ref.listen(coachingChatProvider, (_, next) {
      if (next.valueOrNull?.isNotEmpty == true) _scrollToBottom();
    });

    return Column(
      children: [
        // ── Coaching header strip ────────────────────────────────────
        if (isCoaching)
          _CoachingHeaderStrip(
            scholarship: activeScholarship,
            phase: phase,
            onClear: () {
              ref.read(coachingChatProvider.notifier).clearChat();
              setState(() => _taskPanelExpanded = true);
            },
          ),

        // ── Task Panel ───────────────────────────────────────────────
        if (isCoaching && tasks.isNotEmpty)
          _TaskPanel(
            tasks: tasks,
            isExpanded: _taskPanelExpanded,
            onToggleExpand: () => setState(() => _taskPanelExpanded = !_taskPanelExpanded),
            onToggleTask: (id) => ref.read(coachingTasksProvider.notifier).toggle(id),
            onHelpTask: (task) => _send('Aide-moi avec la tâche : "${task.title}". ${task.description}'),
          ),

        // ── Messages ─────────────────────────────────────────────────
        Expanded(
          child: isLoading && messages.isEmpty
              ? _LoadingBriefing(scholarshipTitle: activeScholarship?.title)
              : messages.isEmpty
                  ? _AgentWelcome(
                      onSwitchToDiscover: () {},
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      itemCount: messages.length + (_isSending ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i == messages.length && _isSending) return const _TypingBubble();
                        final msg = messages[i];
                        return _MessageBubble(role: msg.role, content: msg.content);
                      },
                    ),
        ),

        // ── Confirmation bar ─────────────────────────────────────────
        if (isCoaching && phase == CoachingPhase.awaitingConfirmation)
          _ConfirmationBar(
            onConfirm: () => _send('Oui, je suis prêt(e) à commencer !'),
            onDecline: () => ref.read(coachingChatProvider.notifier).clearChat(),
          ),

        // ── Input bar (only shown while coaching) ────────────────────
        if (isCoaching)
          _InputBar(
            controller: _msgCtrl,
            isSending: _isSending,
            onSend: _send,
            onChanged: () => setState(() {}),
            hint: "Pose une question ou demande de l'aide…",
            extraBottomPadding: inputPadding,
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared Components
// ─────────────────────────────────────────────────────────────────────────────

// ── Assistant Toolbar ────────────────────────────────────────────────────────

class _AssistantToolbar extends StatelessWidget {
  final bool showHistory;
  final VoidCallback onToggleHistory;
  final VoidCallback onNewChat;
  const _AssistantToolbar({required this.showHistory, required this.onToggleHistory, required this.onNewChat});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
      ),
      child: Row(
        children: [
          Text('FlyAssistant 💬',
              style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700)),
          const Spacer(),
          GestureDetector(
            onTap: onNewChat,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF7C3AED)]),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 13, color: Colors.white),
                  SizedBox(width: 4),
                  Text('Nouveau', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onToggleHistory,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: showHistory ? AppColors.primary.withValues(alpha: 0.15) : AppColors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: showHistory ? AppColors.primary.withValues(alpha: 0.5) : AppColors.glassBorder),
              ),
              child: Icon(Icons.history_rounded,
                  size: 18,
                  color: showHistory ? AppColors.primary : AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ── History Panel ────────────────────────────────────────────────────────────

class _HistoryPanel extends StatelessWidget {
  final List<ChatSessionItem> sessions;
  final bool isLoading;
  final void Function(String sessionId) onSelect;
  final VoidCallback onClose;
  final VoidCallback onNewChat;

  const _HistoryPanel({
    required this.sessions,
    required this.isLoading,
    required this.onSelect,
    required this.onClose,
    required this.onNewChat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Text('Conversations', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                GestureDetector(
                  onTap: onClose,
                  child: Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 20),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.glassBorder),
          if (isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
          else if (sessions.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded, size: 48, color: AppColors.glassBorder),
                    const SizedBox(height: 12),
                    Text('Aucune conversation', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: sessions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final s = sessions[i];
                  return GestureDetector(
                    onTap: () => onSelect(s.id),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.history_rounded, color: AppColors.primary, size: 18),
                          const SizedBox(width: 10),
                          Expanded(child: Text(s.title, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600))),
                          Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 16),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ── File Preview Bar ─────────────────────────────────────────────────────────

class _FilePreviewBar extends StatelessWidget {
  final _AttachedFile file;
  final VoidCallback onRemove;
  const _FilePreviewBar({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    IconData iconData = Icons.insert_drive_file_rounded;
    Color iconColor = AppColors.primary;
    if (file.mimeType.contains('pdf')) {
      iconData = Icons.picture_as_pdf_rounded;
      iconColor = Colors.red.shade400;
    } else if (file.mimeType.startsWith('image/')) {
      iconData = Icons.image_rounded;
      iconColor = AppColors.success;
    } else if (file.mimeType.contains('text')) {
      iconData = Icons.text_snippet_rounded;
      iconColor = AppColors.secondary;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(iconData, size: 22, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(file.name,
                    style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
                Text(
                  '${(file.bytes.length / 1024).toStringAsFixed(1)} KB · Prêt à envoyer',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.glassBorder,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close_rounded, size: 14, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Coaching Header Strip ────────────────────────────────────────────────────

class _CoachingHeaderStrip extends StatelessWidget {
  final dynamic scholarship;
  final CoachingPhase phase;
  final VoidCallback onClear;
  const _CoachingHeaderStrip({required this.scholarship, required this.phase, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.school_rounded, color: AppColors.success, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(scholarship?.title ?? '',
                    style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(_phaseLabel(phase),
                    style: AppTextStyles.caption.copyWith(color: _phaseColor(phase))),
              ],
            ),
          ),
          GestureDetector(
            onTap: onClear,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.glassBorder),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Text('Terminer',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
            ),
          ),
        ],
      ),
    );
  }

  Color _phaseColor(CoachingPhase p) {
    switch (p) {
      case CoachingPhase.briefing: return AppColors.primary;
      case CoachingPhase.awaitingConfirmation: return AppColors.secondary;
      case CoachingPhase.coaching: return AppColors.success;
      default: return AppColors.textSecondary;
    }
  }

  String _phaseLabel(CoachingPhase p) {
    switch (p) {
      case CoachingPhase.briefing: return 'Analyse en cours…';
      case CoachingPhase.awaitingConfirmation: return 'En attente de confirmation';
      case CoachingPhase.coaching: return 'Coaching actif ✓';
      default: return 'Prêt';
    }
  }
}

// ── Task Panel ───────────────────────────────────────────────────────────────

class _TaskPanel extends StatelessWidget {
  final List<CoachingTask> tasks;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final void Function(String id) onToggleTask;
  final void Function(CoachingTask task) onHelpTask;

  const _TaskPanel({
    required this.tasks,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onToggleTask,
    required this.onHelpTask,
  });

  @override
  Widget build(BuildContext context) {
    final done = tasks.where((t) => t.isCompleted).length;
    final total = tasks.length;
    final progress = total > 0 ? done / total : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onToggleExpand,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.task_alt_rounded, color: AppColors.success, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Plan d'action · $done/$total",
                            style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 4,
                            backgroundColor: AppColors.glassBorder,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${(progress * 100).round()}%',
                      style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w800, fontSize: 14)),
                  const SizedBox(width: 6),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            child: isExpanded
                ? ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      itemCount: tasks.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.glassBorder),
                      itemBuilder: (_, i) {
                        final task = tasks[i];
                        return _TaskRow(
                          task: task,
                          onToggle: () => onToggleTask(task.id),
                          onHelp: () => onHelpTask(task),
                        );
                      },
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final CoachingTask task;
  final VoidCallback onToggle;
  final VoidCallback onHelp;

  const _TaskRow({required this.task, required this.onToggle, required this.onHelp});

  IconData get _categoryIcon {
    switch (task.category) {
      case 'document': return Icons.description_outlined;
      case 'test': return Icons.assignment_outlined;
      case 'online': return Icons.language_rounded;
      default: return Icons.task_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: task.isCompleted ? AppColors.success : Colors.transparent,
                border: Border.all(
                  color: task.isCompleted ? AppColors.success : AppColors.glassBorder,
                  width: 2,
                ),
              ),
              child: task.isCompleted ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null,
            ),
          ),
          const SizedBox(width: 10),
          Icon(_categoryIcon, size: 14, color: task.isCompleted ? AppColors.textSecondary : AppColors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              task.title,
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: task.isCompleted ? AppColors.textSecondary : AppColors.textPrimary,
                decoration: task.isCompleted ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          if (!task.isCompleted)
            GestureDetector(
              onTap: onHelp,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 11, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text('Aide', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Confirmation Bar ─────────────────────────────────────────────────────────

class _ConfirmationBar extends StatelessWidget {
  final VoidCallback onConfirm;
  final VoidCallback onDecline;
  const _ConfirmationBar({required this.onConfirm, required this.onDecline});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.glassBorder)),
      ),
      child: Row(
        children: [
          Text("Prêt(e) à commencer ?", style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
          const Spacer(),
          GestureDetector(
            onTap: onDecline,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Text('Non', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onConfirm,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF7C3AED)]),
                borderRadius: BorderRadius.circular(50),
                boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 10)],
              ),
              child: const Text('Oui, commençons !', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Loading Briefing ─────────────────────────────────────────────────────────

class _LoadingBriefing extends StatelessWidget {
  final String? scholarshipTitle;
  const _LoadingBriefing({this.scholarshipTitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
            ),
            const SizedBox(height: 24),
            Text('Fly Agent analyse la bourse…', style: AppTextStyles.headlineSmall, textAlign: TextAlign.center),
            if (scholarshipTitle != null) ...[
              const SizedBox(height: 8),
              Text(scholarshipTitle!,
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 16),
            Text(
              "Recherche d'informations et préparation\nde ton plan personnalisé…",
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Agent Welcome (no active scholarship) ────────────────────────────────────

class _AgentWelcome extends StatelessWidget {
  final VoidCallback onSwitchToDiscover;
  const _AgentWelcome({required this.onSwitchToDiscover});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF7C3AED)]),
              boxShadow: [
                BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 28, spreadRadius: 4),
              ],
            ),
            child: const Icon(Icons.school_rounded, size: 44, color: Colors.white),
          ),
          const SizedBox(height: 20),
          Text('Fly Agent 🎯', style: AppTextStyles.headlineLarge.copyWith(fontWeight: FontWeight.w800), textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text(
            "Ton coach IA dédié aux candidatures de bourses.\nAccepte une bourse dans l'onglet Découvrir et\nFly Agent te guidera pas à pas vers le succès.",
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Column(
              children: [
                _AgentFeatureRow(Icons.search_rounded, 'Analyse la bourse en temps réel', 'Recherche sur le web les dernières infos'),
                const SizedBox(height: 14),
                _AgentFeatureRow(Icons.playlist_add_check_rounded, 'Plan d\'action personnalisé', 'Liste de tâches adaptée à ton profil'),
                const SizedBox(height: 14),
                _AgentFeatureRow(Icons.edit_document, 'Rédige tes documents', 'Lettre de motivation, SOP complets et prêts'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentFeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _AgentFeatureRow(this.icon, this.title, this.subtitle);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700)),
              Text(subtitle, style: AppTextStyles.caption),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Assistant Welcome ────────────────────────────────────────────────────────

class _AssistantWelcome extends StatelessWidget {
  final List<(String, IconData, String)> quickActions;
  final void Function(String) onTap;
  const _AssistantWelcome({required this.quickActions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF7C3AED)]),
                    boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 24, spreadRadius: 3)],
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, size: 38, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Text('Fly Assistant 💬', style: AppTextStyles.headlineLarge.copyWith(fontWeight: FontWeight.w800), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  "Pose-moi toutes tes questions sur les bourses.\nTu peux aussi m'envoyer ton CV ou un document\npour que je l'analyse.",
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text('Actions rapides', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...quickActions.map(
            (action) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => onTap(action.$3),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(action.$2, color: AppColors.primary, size: 18),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Text(action.$1, style: AppTextStyles.titleMedium)),
                      Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Message Bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final String role;
  final String content;
  const _MessageBubble({required this.role, required this.content});

  bool get isUser => role == 'user';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(right: 8),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [AppColors.primary, Color(0xFF7C3AED)]),
              ),
              child: const Icon(Icons.auto_awesome_rounded, size: 14, color: Colors.white),
            ),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: isUser
                    ? const LinearGradient(
                        colors: [AppColors.primary, Color(0xFF7C3AED)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isUser ? null : AppColors.card,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                border: isUser ? null : Border.all(color: AppColors.glassBorder),
                boxShadow: [
                  BoxShadow(
                    color: (isUser ? AppColors.primary : Colors.black).withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: isUser
                  ? Text(content, style: AppTextStyles.bodyMedium.copyWith(color: Colors.white, height: 1.55))
                  : MarkdownBody(
                      data: content,
                      styleSheet: MarkdownStyleSheet(
                        p: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary, height: 1.55),
                        h1: AppTextStyles.headlineSmall.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w800),
                        h2: AppTextStyles.titleLarge.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                        h3: AppTextStyles.titleMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                        strong: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                        em: const TextStyle(color: AppColors.textPrimary, fontStyle: FontStyle.italic),
                        code: TextStyle(
                          color: AppColors.primary,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                        blockquote: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                        listBullet: AppTextStyles.bodyMedium.copyWith(color: AppColors.primary),
                        horizontalRuleDecoration: BoxDecoration(
                          border: Border(top: BorderSide(color: AppColors.glassBorder, width: 1)),
                        ),
                      ),
                    ),
            ),
          ),
          if (isUser) const SizedBox(width: 4),
        ],
      ),
    );
  }
}

// ── Input Bar ────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;
  final VoidCallback onChanged;
  final VoidCallback? onAttach;
  final String hint;
  final double extraBottomPadding;

  const _InputBar({
    required this.controller,
    required this.isSending,
    required this.onSend,
    required this.onChanged,
    this.onAttach,
    required this.hint,
    this.extraBottomPadding = 32,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, extraBottomPadding),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.glassBorder, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Attach file button
          if (onAttach != null)
            GestureDetector(
              onTap: onAttach,
              child: Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.only(right: 8, bottom: 4),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Icon(Icons.attach_file_rounded, size: 18, color: AppColors.textSecondary),
              ),
            ),

          // Text field
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: TextField(
                controller: controller,
                maxLines: null,
                textInputAction: TextInputAction.newline,
                onChanged: (_) => onChanged(),
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Send button
          GestureDetector(
            onTap: isSending ? null : onSend,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: controller.text.trim().isNotEmpty && !isSending
                      ? [AppColors.primary, const Color(0xFF7C3AED)]
                      : [AppColors.glassBorder, AppColors.glassBorder],
                ),
              ),
              child: isSending
                  ? const Padding(
                      padding: EdgeInsets.all(13),
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Typing Bubble ────────────────────────────────────────────────────────────

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();
  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(right: 8),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [AppColors.primary, Color(0xFF7C3AED)]),
            ),
            child: const Icon(Icons.auto_awesome_rounded, size: 14, color: Colors.white),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: AnimatedBuilder(
              animation: _anim,
              builder: (_, __) => Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  final opacity = i == 0 ? _anim.value : i == 1 ? (_anim.value + 0.3).clamp(0.0, 1.0) : 0.4;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: opacity),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
