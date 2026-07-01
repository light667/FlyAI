import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/utils/pdf_generator.dart';
import '../models/chat_message_model.dart';
import '../providers/chat_provider.dart';

// ── AI Assistant Screen ───────────────────────────────────────────────────

class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isSending = false;

  final _quickActions = [
    ('Review my CV', 'Can you help me review my CV and suggest improvements?'),
    ('Write a motivation letter', 'Help me write a compelling motivation letter for a scholarship.'),
    ('Interview prep', 'Help me prepare for a scholarship interview.'),
    ('SOP tips', 'Give me tips for writing a strong Statement of Purpose.'),
    ('Scholarship strategy', 'What strategy should I use to maximize my scholarship applications?'),
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

    setState(() => _isSending = true);
    _msgCtrl.clear();

    await ref.read(chatProvider.notifier).sendMessage(content);
    setState(() => _isSending = false);

    await Future.delayed(const Duration(milliseconds: 100));
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatProvider);
    final messages = messagesAsync.valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                ),
              ),
              child: const Icon(Icons.auto_awesome_rounded, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Text(AppStrings.flyAssistant, style: AppTextStyles.headlineSmall),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'New chat',
            onPressed: () => ref.read(chatProvider.notifier).clearChat(),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Messages ─────────────────────────────────────────────────────
          Expanded(
            child: messages.isEmpty
                ? _WelcomeView(
                    quickActions: _quickActions,
                    onTap: _send,
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: messages.length + (_isSending ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == messages.length && _isSending) {
                        return const _TypingIndicator();
                      }
                      return _MessageBubble(message: messages[i]);
                    },
                  ),
          ),

          // ── Input Bar ─────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: BoxDecoration(
              color: AppColors.card,
              border: Border(top: BorderSide(color: AppColors.glassBorder)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _msgCtrl,
                    label: '',
                    hint: AppStrings.askAnything,
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.newline,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  child: GestureDetector(
                    onTap: _isSending ? null : () => _send(),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: _msgCtrl.text.trim().isNotEmpty && !_isSending
                              ? [AppColors.primary, AppColors.secondary]
                              : [AppColors.glassBorder, AppColors.glassBorder],
                        ),
                      ),
                      child: _isSending
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeView extends StatelessWidget {
  final List<(String, String)> quickActions;
  final void Function(String) onTap;

  const _WelcomeView({required this.quickActions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 20),
          Text(AppStrings.flyAssistant, style: AppTextStyles.headlineLarge),
          const SizedBox(height: 8),
          Text(
            'Your AI scholarship advisor',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Text(
              AppStrings.assistantWelcome,
              style: AppTextStyles.bodyMedium.copyWith(height: 1.6),
            ),
          ),
          const SizedBox(height: 24),
          Text('Quick Actions', style: AppTextStyles.titleMedium),
          const SizedBox(height: 12),
          ...quickActions.map(
            (action) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => onTap(action.$2),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: Text(action.$1, style: AppTextStyles.bodyMedium),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  bool get isUser => message.role == 'user';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                ),
              ),
              child: const Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primary : AppColors.card,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                border: isUser ? null : Border.all(color: AppColors.glassBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.content,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isUser ? Colors.white : AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                  if (!isUser && message.content.length > 200) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          backgroundColor: AppColors.background,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: AppColors.glassBorder),
                          ),
                        ),
                        onPressed: () {
                          String title = 'Motivation Letter';
                          final contentLower = message.content.toLowerCase();
                          if (contentLower.contains('curriculum vitae') || contentLower.contains('cv')) {
                            title = 'CV Feedback Analysis';
                          } else if (contentLower.contains('sop') || contentLower.contains('statement of purpose')) {
                            title = 'Statement of Purpose Draft';
                          } else if (contentLower.contains('checklist') || contentLower.contains('document')) {
                            title = 'Application Checklist Strategy';
                          }
                          PdfGenerator.generateAndShare(
                            title: title,
                            content: message.content,
                          );
                        },
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 14, color: AppColors.primary),
                        label: const Text(
                          'Export PDF',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
              ),
            ),
            child: const Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                3,
                (i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _Dot(delay: i * 200),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _anim.value),
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
