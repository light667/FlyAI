import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
//import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../profile/models/profile_model.dart';

class DirectMessageModel {
  final String id;
  final String senderUid;
  final String receiverUid;
  final String content;
  final bool isRead;
  final DateTime createdAt;

  const DirectMessageModel({
    required this.id,
    required this.senderUid,
    required this.receiverUid,
    required this.content,
    required this.isRead,
    required this.createdAt,
  });

  factory DirectMessageModel.fromJson(Map<String, dynamic> json) {
    return DirectMessageModel(
      id: json['id'] as String? ?? '',
      senderUid: json['sender_uid'] as String? ?? '',
      receiverUid: json['receiver_uid'] as String? ?? '',
      content: json['content'] as String? ?? '',
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class DirectChatScreen extends ConsumerStatefulWidget {
  final String peerId;
  final ProfileModel? peerProfile;

  const DirectChatScreen({
    super.key,
    required this.peerId,
    this.peerProfile,
  });

  @override
  ConsumerState<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends ConsumerState<DirectChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<DirectMessageModel> _messages = [];
  bool _isLoading = true;
  Timer? _pollingTimer;
  ProfileModel? _peerProfile;

  @override
  void initState() {
    super.initState();
    _peerProfile = widget.peerProfile;
    _fetchPeerProfileIfNeeded();
    _fetchMessages();
    // Start polling every 3 seconds to get real-time conversation updates
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) => _fetchMessages(silent: true));
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchPeerProfileIfNeeded() async {
    if (_peerProfile != null) return;
    try {
      final json = await SupabaseService.fetchOne('profiles', 'firebase_uid', widget.peerId);
      if (json != null && mounted) {
        setState(() {
          _peerProfile = ProfileModel.fromJson(json);
        });
      }
    } catch (_) {}
  }

  Future<void> _markMessagesAsRead() async {
    final user = AuthService.currentUser;
    if (user == null) return;
    try {
      await SupabaseService.client
          .from('direct_messages')
          .update({'is_read': true})
          .eq('sender_uid', widget.peerId)
          .eq('receiver_uid', user.uid)
          .eq('is_read', false);
    } catch (_) {}
  }

  Future<void> _fetchMessages({bool silent = false}) async {
    final user = AuthService.currentUser;
    if (user == null) return;

    if (!silent && mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final response = await SupabaseService.client
          .from('direct_messages')
          .select()
          .or('and(sender_uid.eq.${user.uid},receiver_uid.eq.${widget.peerId}),and(sender_uid.eq.${widget.peerId},receiver_uid.eq.${user.uid})')
          .order('created_at', ascending: true);

      final loaded = (response as List)
          .map((json) => DirectMessageModel.fromJson(json as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _messages = loaded;
          _isLoading = false;
        });
        
        // Scroll to bottom on initial load
        if (!silent) {
          Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
        }

        _markMessagesAsRead();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _deleteMessage(DirectMessageModel msg) async {
    final user = AuthService.currentUser;
    if (user == null || msg.senderUid != user.uid) return;
    try {
      await SupabaseService.client
          .from('direct_messages')
          .delete()
          .eq('id', msg.id);
      await _fetchMessages(silent: true);
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    final user = AuthService.currentUser;
    if (user == null) return;

    _msgCtrl.clear();

    try {
      await SupabaseService.client.from('direct_messages').insert({
        'sender_uid': user.uid,
        'receiver_uid': widget.peerId,
        'content': text,
      });

      // Instantly fetch to show the message
      _fetchMessages(silent: true);
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final peerName = _peerProfile?.fullName ?? 'Scholar';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              backgroundImage: _peerProfile?.photoUrl != null
                  ? NetworkImage(_peerProfile!.photoUrl!)
                  : null,
              child: _peerProfile?.photoUrl == null
                  ? Text(
                      peerName.isNotEmpty ? peerName[0].toUpperCase() : 'S',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(peerName, style: AppTextStyles.titleMedium),
                  if (_peerProfile?.university != null && _peerProfile!.university.isNotEmpty)
                    Text(
                      _peerProfile!.university,
                      style: AppTextStyles.caption.copyWith(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Message feed
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _messages.isEmpty
                    ? _EmptyChatView(peerName: peerName)
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          return _MessageBubble(
                            message: msg,
                            onDelete: () => _deleteMessage(msg),
                          );
                        },
                      ),
          ),

          // Message Input Bar
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16,
                MediaQuery.of(context).padding.bottom + 12),
            decoration: BoxDecoration(
              color: AppColors.card,
              border: Border(top: BorderSide(color: AppColors.glassBorder)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: TextField(
                      controller: _msgCtrl,
                      // Fixed: was Colors.white which blended into the white background
                      style: TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Écris un message...',
                        hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.6)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                          colors: [AppColors.primary, Color(0xFF7C3AED)]),
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
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

class _MessageBubble extends StatelessWidget {
  final DirectMessageModel message;
  final VoidCallback? onDelete;

  const _MessageBubble({required this.message, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    final isMe = message.senderUid == user?.uid;
    final timeStr = DateFormat('HH:mm').format(message.createdAt);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Delete icon — only for own messages, placed before the bubble when right-aligned
          if (isMe && onDelete != null)
            GestureDetector(
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppColors.card,
                    title: Text('Supprimer ce message?',
                        style: TextStyle(color: AppColors.textPrimary)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text('Annuler', style: TextStyle(color: AppColors.textSecondary)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) onDelete?.call();
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 6, bottom: 4),
                child: Icon(Icons.delete_outline_rounded,
                    size: 16, color: AppColors.textSecondary.withValues(alpha: 0.6)),
              ),
            ),

          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppColors.primary : AppColors.card,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                border: isMe ? null : Border.all(color: AppColors.glassBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.content,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isMe ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeStr,
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 9,
                          color: isMe ? Colors.white60 : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}




class _EmptyChatView extends StatelessWidget {
  final String peerName;

  const _EmptyChatView({required this.peerName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat_bubble_outline_rounded, size: 64, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'No messages yet',
              style: AppTextStyles.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Say hello to $peerName! Start your conversation about scholarships and applications.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
