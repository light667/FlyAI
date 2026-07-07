import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../profile/models/profile_model.dart';
import 'direct_chat_screen.dart';
import 'member_profile_screen.dart';

// ── Post Model ─────────────────────────────────────────────────────────────

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
    required this.id, required this.firebaseUid, required this.authorName,
    this.authorPhoto, required this.content, required this.tags,
    this.likesCount = 0, this.commentsCount = 0, required this.createdAt,
    this.isLiked = false,
  });

  factory PostModel.fromJson(Map<String, dynamic> json,
      {bool isLiked = false}) {
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
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }
}

// ── Community Feed Screen ─────────────────────────────────────────────────

class CommunityFeedScreen extends ConsumerStatefulWidget {
  const CommunityFeedScreen({super.key});
  @override
  ConsumerState<CommunityFeedScreen> createState() =>
      _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends ConsumerState<CommunityFeedScreen> {
  int _tabIndex = 0; // 0 = Posts, 1 = Membres

  // Posts state
  List<PostModel> _posts = [];
  bool _postsLoading = true;

  // Members state
  List<ProfileModel> _members = [];
  bool _membersLoading = false;
  bool _membersLoaded = false;

  final _suggestedTags = [
    'Bourse', 'Conseil', 'Motivation', 'Succès',
    'Deadline', 'Entretien', 'CV', 'SOP',
  ];

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  // ── Data fetching ──────────────────────────────────────────────────────

  Future<void> _loadPosts() async {
    if (!mounted) return;
    setState(() => _postsLoading = true);
    try {
      final user = AuthService.currentUser;
      final rows = await SupabaseService.client
          .from('posts')
          .select()
          .order('created_at', ascending: false)
          .limit(40);

      Set<String> likedIds = {};
      if (user != null) {
        try {
          final likes = await SupabaseService.client
              .from('post_likes')
              .select('post_id')
              .eq('firebase_uid', user.uid);
          likedIds =
              (likes as List).map((r) => r['post_id'] as String).toSet();
        } catch (_) {
          // If post_likes table is missing, fail silently and keep empty likedIds
        }
      }

      if (!mounted) return;
      setState(() {
        _posts = (rows as List)
            .map((r) => PostModel.fromJson(r as Map<String, dynamic>,
                isLiked: likedIds.contains(r['id'])))
            .toList();
        _postsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _postsLoading = false);
    }
  }

  Future<void> _loadMembers() async {
    if (_membersLoaded || !mounted) return;
    setState(() => _membersLoading = true);
    try {
      final user = AuthService.currentUser;
      final rows = await SupabaseService.client
          .from('profiles')
          .select()
          .order('created_at', ascending: false)
          .limit(100);

      if (!mounted) return;
      final all = (rows as List)
          .map((r) {
            try {
              return ProfileModel.fromJson(r as Map<String, dynamic>);
            } catch (_) {
              return null;
            }
          })
          .whereType<ProfileModel>()
          .where((p) => p.firebaseUid != (user?.uid ?? ''))
          .toList();

      setState(() {
        _members = all;
        _membersLoading = false;
        _membersLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _membersLoading = false);
    }
  }

  Future<void> _toggleLike(PostModel post) async {
    final user = AuthService.currentUser;
    if (user == null) return;
    // Optimistic update
    if (!mounted) return;
    setState(() => post.isLiked = !post.isLiked);
    try {
      if (post.isLiked) {
        await SupabaseService.client.from('post_likes')
            .insert({'firebase_uid': user.uid, 'post_id': post.id});
      } else {
        await SupabaseService.client.from('post_likes')
            .delete()
            .eq('firebase_uid', user.uid)
            .eq('post_id', post.id);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => post.isLiked = !post.isLiked);
    }
  }

  void _openCreatePost() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (ctx) => _CreatePostModal(
        suggestedTags: _suggestedTags,
        onSubmit: (content, tags) async {
          final user = AuthService.currentUser;
          if (user == null || content.isEmpty) return;
          try {
            final profile = await SupabaseService.fetchOne(
                'profiles', 'firebase_uid', user.uid);
            final name =
                profile?['full_name'] as String? ?? user.displayName ?? 'Scholar';
            final photo = profile?['photo_url'] as String? ?? user.photoURL;
            await SupabaseService.client.from('posts').insert({
              'firebase_uid': user.uid,
              'author_name': name,
              'author_photo': photo,
              'content': content,
              'tags': tags,
            });
            if (ctx.mounted) Navigator.pop(ctx);
            _loadPosts();
          } catch (e) {
            if (ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text('Erreur lors de la publication : $e'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _switchTab(int i) {
    setState(() => _tabIndex = i);
    if (i == 1 && !_membersLoaded) _loadMembers();
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
              child: Row(
                children: [
                  Text('Communauté',
                      style: AppTextStyles.displayMedium
                          .copyWith(fontWeight: FontWeight.w800)),
                  const Spacer(),
                  if (_tabIndex == 0)
                    GestureDetector(
                      onTap: _openCreatePost,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [
                            AppColors.primary,
                            Color(0xFF7C3AED)
                          ]),
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: [
                            BoxShadow(
                                color: AppColors.primary
                                    .withValues(alpha: 0.3),
                                blurRadius: 10)
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_rounded,
                                size: 14, color: Colors.white),
                            SizedBox(width: 6),
                            Text('Publier',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Tab bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Row(
              children: [
                _TabBtn('Posts', 0, _tabIndex, onTap: () => _switchTab(0)),
                const SizedBox(width: 8),
                _TabBtn('Membres', 1, _tabIndex,
                    onTap: () => _switchTab(1)),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.glassBorder,
              indent: 20, endIndent: 20),
          const SizedBox(height: 4),

          // Content
          Expanded(
            child: _tabIndex == 0
                ? _PostsTab(
                    posts: _posts,
                    isLoading: _postsLoading,
                    onRefresh: _loadPosts,
                    onLike: _toggleLike,
                    onMessage: _openDM,
                    onPost: _openCreatePost,
                    onDelete: _deletePost,
                  )
                : _MembersTab(
                    members: _members,
                    isLoading: _membersLoading,
                    onMessage: _openDM,
                    onProfile: _openMemberProfile,
                  ),
          ),
        ],
      ),
    );
  }

  void _openDM(String peerId, [ProfileModel? profile]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DirectChatScreen(
          peerId: peerId,
          peerProfile: profile,
        ),
      ),
    );
  }

  void _openMemberProfile(ProfileModel profile) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MemberProfileScreen(profile: profile),
      ),
    );
  }

  Future<void> _deletePost(PostModel post) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Supprimer ce post?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text('Cette action est irréversible.',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await SupabaseService.client
          .from('posts')
          .delete()
          .eq('id', post.id);
      await _loadPosts();
    } catch (_) {}
  }
}

// ── Tab button ─────────────────────────────────────────────────────────────

class _TabBtn extends StatelessWidget {
  final String label;
  final int index;
  final int current;
  final VoidCallback onTap;

  const _TabBtn(this.label, this.index, this.current, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = index == current;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
              color: active ? AppColors.primary : AppColors.glassBorder),
        ),
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

// ── Posts Tab ──────────────────────────────────────────────────────────────

class _PostsTab extends StatelessWidget {
  final List<PostModel> posts;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final void Function(PostModel) onLike;
  final void Function(String peerId, [ProfileModel?]) onMessage;
  final VoidCallback onPost;
  final void Function(PostModel) onDelete;

  const _PostsTab({
    required this.posts, required this.isLoading,
    required this.onRefresh, required this.onLike,
    required this.onMessage, required this.onPost,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (posts.isEmpty) {
      return _EmptyPosts(onPost: onPost);
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        itemCount: posts.length,
        itemBuilder: (_, i) => _PostCard(
          post: posts[i],
          onLike: () => onLike(posts[i]),
          onMessage: () => onMessage(posts[i].firebaseUid),
          onDelete: () => onDelete(posts[i]),
        ),
      ),
    );
  }
}

// ── Members Tab ────────────────────────────────────────────────────────────

class _MembersTab extends StatelessWidget {
  final List<ProfileModel> members;
  final bool isLoading;
  final void Function(String peerId, [ProfileModel?]) onMessage;
  final void Function(ProfileModel)? onProfile;

  const _MembersTab({
    required this.members, required this.isLoading,
    required this.onMessage, this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (members.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_outlined,
                size: 56, color: AppColors.glassBorder),
            const SizedBox(height: 16),
            Text('Aucun membre pour l\'instant',
                style: AppTextStyles.headlineSmall),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      itemCount: members.length,
      itemBuilder: (_, i) => _MemberCard(
        profile: members[i],
        onMessage: () => onMessage(members[i].firebaseUid, members[i]),
        onProfile: onProfile != null ? () => onProfile!(members[i]) : null,
      ),
    );
  }
}

// ── Member Card ────────────────────────────────────────────────────────────

class _MemberCard extends StatelessWidget {
  final ProfileModel profile;
  final VoidCallback onMessage;
  final VoidCallback? onProfile;

  const _MemberCard({required this.profile, required this.onMessage, this.onProfile});

  @override
  Widget build(BuildContext context) {
    final name = profile.fullName.trim().isNotEmpty
        ? profile.fullName
        : 'Scholar';
    final initial =
        name.isNotEmpty ? name[0].toUpperCase() : 'S';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onProfile,
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                          colors: [AppColors.primary, Color(0xFF7C3AED)]),
                    ),
                    child: profile.photoUrl != null && profile.photoUrl!.isNotEmpty
                        ? ClipOval(
                            child: Image.network(profile.photoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _InitialAvatar(initial: initial)))
                        : _InitialAvatar(initial: initial),
                  ),
                  const SizedBox(width: 12),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: AppTextStyles.titleMedium
                                .copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        if (profile.fieldOfStudy.isNotEmpty ||
                            profile.university.isNotEmpty)
                          Text(
                            [
                              if (profile.fieldOfStudy.isNotEmpty)
                                profile.fieldOfStudy,
                              if (profile.university.isNotEmpty) profile.university,
                            ].join(' · '),
                            style: AppTextStyles.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (profile.country.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.location_on_rounded,
                                  size: 11,
                                  color: AppColors.textSecondary),
                              const SizedBox(width: 3),
                              Text(profile.country,
                                  style: AppTextStyles.caption),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Message button
          GestureDetector(
            onTap: onMessage,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_bubble_outline_rounded,
                      size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text('Message',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  final String initial;
  const _InitialAvatar({required this.initial});
  @override
  Widget build(BuildContext context) => Center(
        child: Text(initial,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18)),
      );
}

// ── Post Card ──────────────────────────────────────────────────────────────

class _PostCard extends StatelessWidget {
  final PostModel post;
  final VoidCallback onLike;
  final VoidCallback onMessage;
  final VoidCallback onDelete;

  const _PostCard({
    required this.post,
    required this.onLike,
    required this.onMessage,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    final isOwn = post.firebaseUid == user?.uid;
    final initial = post.authorName.isNotEmpty
        ? post.authorName[0].toUpperCase()
        : 'S';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [
                      AppColors.primary,
                      Color(0xFF7C3AED)
                    ]),
                  ),
                  child: post.authorPhoto != null
                      ? ClipOval(
                          child: Image.network(post.authorPhoto!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _InitialAvatar(initial: initial)))
                      : _InitialAvatar(initial: initial),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.authorName,
                          style: AppTextStyles.titleMedium
                              .copyWith(fontWeight: FontWeight.w700)),
                      Text(_formatTime(post.createdAt),
                          style: AppTextStyles.caption),
                    ],
                  ),
                ),
                if (!isOwn)
                  GestureDetector(
                    onTap: onMessage,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 16,
                          color: AppColors.primary),
                    ),
                  ),
                if (isOwn)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert_rounded,
                        color: AppColors.textSecondary, size: 20),
                    color: AppColors.card,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    onSelected: (v) {
                      if (v == 'delete') onDelete();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(Icons.delete_outline_rounded,
                                color: Colors.red, size: 18),
                            const SizedBox(width: 8),
                            Text('Supprimer',
                                style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Text(post.content,
                style: AppTextStyles.bodyMedium.copyWith(height: 1.55)),
          ),

          // Tags
          if (post.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: post.tags
                    .map((t) => Text('#$t',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)))
                    .toList(),
              ),
            ),

          // Action bar — GestureDetector avoids mouse_tracker issues
          Container(
            decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(color: AppColors.glassBorder))),
            child: Row(
              children: [
                _ActionBtn(
                  icon: post.isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_outline_rounded,
                  label: '${post.likesCount + (post.isLiked ? 1 : 0)}',
                  color: post.isLiked
                      ? AppColors.error
                      : AppColors.textSecondary,
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
                  label: 'Partager',
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
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inHours < 1) return '${diff.inMinutes}min';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}j';
    return DateFormat('d MMM', 'fr').format(dt);
  }
}

// ── Action button (GestureDetector, not InkWell) ───────────────────────────
// Using GestureDetector instead of TextButton/InkWell avoids the
// mouse hover tracking that causes mouse_tracker.dart:199 on Flutter Web.

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn(
      {required this.icon, required this.label,
       required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Create Post Modal (NO DraggableScrollableSheet) ────────────────────────

class _CreatePostModal extends StatefulWidget {
  final List<String> suggestedTags;
  final Future<void> Function(String content, List<String> tags) onSubmit;

  const _CreatePostModal(
      {required this.suggestedTags, required this.onSubmit});

  @override
  State<_CreatePostModal> createState() => _CreatePostModalState();
}

class _CreatePostModalState extends State<_CreatePostModal> {
  final _ctrl = TextEditingController();
  final List<String> _selectedTags = [];
  bool _submitting = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_ctrl.text.trim().isEmpty || _submitting) return;
    setState(() => _submitting = true);
    await widget.onSubmit(_ctrl.text.trim(), List.from(_selectedTags));
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: EdgeInsets.only(bottom: bottom),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.glassBorder,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),

            // Title row
            Row(
              children: [
                Text('Partager avec la communauté',
                    style: AppTextStyles.headlineSmall
                        .copyWith(fontWeight: FontWeight.w800)),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close_rounded,
                      color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Text field
            TextField(
              controller: _ctrl,
              maxLines: 5,
              autofocus: true,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText:
                    'Partage ton expérience, tes conseils ou ton succès…',
                hintStyle: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        BorderSide(color: AppColors.glassBorder)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        BorderSide(color: AppColors.glassBorder)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                        color: AppColors.primary, width: 1.5)),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 14),

            // Tags
            Text('Tags',
                style: AppTextStyles.bodySmall
                    .copyWith(fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: widget.suggestedTags.map((tag) {
                final sel = _selectedTags.contains(tag);
                return GestureDetector(
                  onTap: () => setState(() =>
                      sel ? _selectedTags.remove(tag)
                          : _selectedTags.add(tag)),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel
                          ? AppColors.primary
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(
                          color: sel
                              ? AppColors.primary
                              : AppColors.glassBorder),
                    ),
                    child: Text('#$tag',
                        style: TextStyle(
                            color: sel
                                ? Colors.white
                                : AppColors.textSecondary,
                            fontWeight: sel
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 12)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Submit button
            GestureDetector(
              onTap: _submitting ? null : _submit,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [AppColors.primary, Color(0xFF7C3AED)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 14,
                        offset: const Offset(0, 5))
                  ],
                ),
                child: Center(
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.send_rounded,
                                color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text('Publier',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15)),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty posts ────────────────────────────────────────────────────────────

class _EmptyPosts extends StatelessWidget {
  final VoidCallback onPost;
  const _EmptyPosts({required this.onPost});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.1)),
              child: const Icon(Icons.forum_rounded,
                  size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text('Sois le premier à publier !',
                style: AppTextStyles.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Partage tes conseils, ton parcours\nou pose des questions à la communauté.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onPost,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [AppColors.primary, Color(0xFF7C3AED)]),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Text('Créer un post',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
