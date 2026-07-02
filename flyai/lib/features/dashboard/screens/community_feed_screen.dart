import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/providers/locale_provider.dart';
import '../../profile/models/profile_model.dart';
import 'direct_chat_screen.dart';

// ── PostModel (unchanged) ─────────────────────────────────────────────────

class PostModel {
  final String id;
  final String firebaseUid;
  final String authorName;
  final String? authorPhoto;
  final String content;
  final List<String> tags;
  final int likesCount;
  final int commentsCount;
  final DateTime createdAt;
  bool isLiked;

  PostModel({
    required this.id,
    required this.firebaseUid,
    required this.authorName,
    this.authorPhoto,
    required this.content,
    required this.tags,
    this.likesCount = 0,
    this.commentsCount = 0,
    required this.createdAt,
    this.isLiked = false,
  });

  factory PostModel.fromJson(Map<String, dynamic> json, {bool isLiked = false}) {
    return PostModel(
      id: json['id'] as String? ?? '',
      firebaseUid: json['firebase_uid'] as String? ?? '',
      authorName: json['author_name'] as String? ?? 'Scholar',
      authorPhoto: json['author_photo'] as String?,
      content: json['content'] as String? ?? '',
      tags: _parseList(json['tags']),
      likesCount: json['likes_count'] as int? ?? 0,
      commentsCount: json['comments_count'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      isLiked: isLiked,
    );
  }

  static List<String> _parseList(dynamic v) {
    if (v == null) return [];
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }

  Map<String, dynamic> toJson() => {
        'firebase_uid': firebaseUid,
        'author_name': authorName,
        'author_photo': authorPhoto,
        'content': content,
        'tags': tags,
      };
}

// ── Community Feed Screen ─────────────────────────────────────────────────

class CommunityFeedScreen extends ConsumerStatefulWidget {
  const CommunityFeedScreen({super.key});
  @override
  ConsumerState<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends ConsumerState<CommunityFeedScreen> {
  List<PostModel> _posts = [];
  bool _isLoading = true;
  final _postCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();
  List<String> _selectedTags = [];
  Set<String> _likedIds = {};

  final _suggestedTags = ['Scholarship', 'Tips', 'Motivation', 'Success', 'Deadline', 'Interview', 'CV', 'SOP'];

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  @override
  void dispose() {
    _postCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);
    try {
      final user = AuthService.currentUser;
      final rows = await SupabaseService.client
          .from('community_posts')
          .select()
          .order('created_at', ascending: false)
          .limit(40);

      Set<String> likedIds = {};
      if (user != null) {
        final likes = await SupabaseService.client
            .from('post_likes')
            .select('post_id')
            .eq('firebase_uid', user.uid);
        likedIds = (likes as List).map((r) => r['post_id'] as String).toSet();
      }

      if (mounted) {
        setState(() {
          _posts = (rows as List)
              .map((r) => PostModel.fromJson(r as Map<String, dynamic>, isLiked: likedIds.contains(r['id'])))
              .toList();
          _likedIds = likedIds;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLike(PostModel post) async {
    final user = AuthService.currentUser;
    if (user == null) return;
    setState(() => post.isLiked = !post.isLiked);
    try {
      if (post.isLiked) {
        await SupabaseService.client.from('post_likes').insert({'firebase_uid': user.uid, 'post_id': post.id});
      } else {
        await SupabaseService.client.from('post_likes').delete().eq('firebase_uid', user.uid).eq('post_id', post.id);
      }
    } catch (_) {
      setState(() => post.isLiked = !post.isLiked);
    }
  }

  Future<void> _submitPost() async {
    final content = _postCtrl.text.trim();
    if (content.isEmpty) return;
    final user = AuthService.currentUser;
    if (user == null) return;

    final profile = await SupabaseService.fetchOne('profiles', 'firebase_uid', user.uid);
    final name = profile?['full_name'] as String? ?? user.displayName ?? 'Scholar';
    final photo = profile?['photo_url'] as String? ?? user.photoURL;

    try {
      await SupabaseService.client.from('community_posts').insert({
        'firebase_uid': user.uid,
        'author_name': name,
        'author_photo': photo,
        'content': content,
        'tags': _selectedTags,
      });
      _postCtrl.clear();
      _selectedTags = [];
      Navigator.pop(context);
      _loadPosts();
    } catch (_) {}
  }

  void _showPostModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreatePostSheet(
        controller: _postCtrl,
        tagCtrl: _tagCtrl,
        selectedTags: _selectedTags,
        suggestedTags: _suggestedTags,
        onTagToggle: (tag) => setState(() {
          _selectedTags.contains(tag) ? _selectedTags.remove(tag) : _selectedTags.add(tag);
        }),
        onSubmit: _submitPost,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _loadPosts,
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            // ── Header ────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 60, 24, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Community',
                        style: AppTextStyles.displayMedium.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    GestureDetector(
                      onTap: _showPostModal,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, Color(0xFF7C3AED)],
                          ),
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: [
                            BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 10),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.edit_rounded, size: 14, color: Colors.white),
                            SizedBox(width: 6),
                            Text('Post', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Feed ──────────────────────────────────────────────────────
            _isLoading
                ? const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    ),
                  )
                : _posts.isEmpty
                    ? SliverToBoxAdapter(child: _EmptyCommunity(onPost: _showPostModal))
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            if (i < _posts.length) {
                              return _PostCard(
                                post: _posts[i],
                                onLike: () => _toggleLike(_posts[i]),
                                onMessage: () {
                                  final user = AuthService.currentUser;
                                  if (user == null || _posts[i].firebaseUid == user.uid) return;
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DirectChatScreen(peerId: _posts[i].firebaseUid),
                                    ),
                                  );
                                },
                              );
                            }
                            return const SizedBox(height: 120);
                          },
                          childCount: _posts.length + 1,
                        ),
                      ),
          ],
        ),
      ),
    );
  }
}

// ── Post Card ─────────────────────────────────────────────────────────────

class _PostCard extends StatelessWidget {
  final PostModel post;
  final VoidCallback onLike;
  final VoidCallback onMessage;
  const _PostCard({required this.post, required this.onLike, required this.onMessage});

  @override
  Widget build(BuildContext context) {
    final timeAgo = _formatTime(post.createdAt);
    final user = AuthService.currentUser;
    final isOwn = post.firebaseUid == user?.uid;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.glassBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, Color(0xFF7C3AED)],
                    ),
                  ),
                  child: post.authorPhoto != null
                      ? ClipOval(child: Image.network(post.authorPhoto!, fit: BoxFit.cover))
                      : Center(
                          child: Text(
                            post.authorName.isNotEmpty ? post.authorName[0].toUpperCase() : 'S',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.authorName, style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700)),
                      Text(timeAgo, style: AppTextStyles.caption),
                    ],
                  ),
                ),
                if (!isOwn)
                  GestureDetector(
                    onTap: onMessage,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: AppColors.primary),
                    ),
                  ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Text(
              post.content,
              style: AppTextStyles.bodyMedium.copyWith(height: 1.55),
            ),
          ),

          // Tags
          if (post.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: post.tags
                    .map((t) => Text(
                          '#$t',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ))
                    .toList(),
              ),
            ),

          // Actions bar
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.glassBorder)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                _ActionBtn(
                  icon: post.isLiked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                  label: '${post.likesCount + (post.isLiked ? 1 : 0)}',
                  color: post.isLiked ? AppColors.error : AppColors.textSecondary,
                  onTap: onLike,
                ),
                _ActionBtn(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: '${post.commentsCount}',
                  color: AppColors.textSecondary,
                  onTap: () {},
                ),
                _ActionBtn(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  color: AppColors.textSecondary,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: color),
        label: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

// ── Create Post Sheet ──────────────────────────────────────────────────────

class _CreatePostSheet extends StatelessWidget {
  final TextEditingController controller;
  final TextEditingController tagCtrl;
  final List<String> selectedTags;
  final List<String> suggestedTags;
  final void Function(String) onTagToggle;
  final VoidCallback onSubmit;

  const _CreatePostSheet({
    required this.controller,
    required this.tagCtrl,
    required this.selectedTags,
    required this.suggestedTags,
    required this.onTagToggle,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, sc) => Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.glassBorder, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Text('Share with the community', style: AppTextStyles.headlineSmall.copyWith(fontWeight: FontWeight.w800)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                controller: sc,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  TextField(
                    controller: controller,
                    maxLines: 6,
                    autofocus: true,
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Share your scholarship journey, tips, or success story…',
                      hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: AppColors.glassBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: AppColors.glassBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Add tags', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: suggestedTags.map((tag) {
                      final isSelected = selectedTags.contains(tag);
                      return GestureDetector(
                        onTap: () => onTagToggle(tag),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : AppColors.background,
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(color: isSelected ? AppColors.primary : AppColors.glassBorder),
                          ),
                          child: Text(
                            '#$tag',
                            style: TextStyle(
                              color: isSelected ? Colors.white : AppColors.textSecondary,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: onSubmit,
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, Color(0xFF7C3AED)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
                      ),
                      child: const Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.send_rounded, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text('Publish', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCommunity extends StatelessWidget {
  final VoidCallback onPost;
  const _EmptyCommunity({required this.onPost});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withOpacity(0.1),
            ),
            child: const Icon(Icons.forum_rounded, size: 44, color: AppColors.primary),
          ),
          const SizedBox(height: 20),
          Text('Be the first to post!', style: AppTextStyles.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Share tips, success stories, or questions with other scholars.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: onPost,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF7C3AED)]),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Text('Create a post', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
