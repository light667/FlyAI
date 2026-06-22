import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/providers/locale_provider.dart';

// ── Models ───────────────────────────────────────────────────────────────────

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
  final bool isLiked;

  const PostModel({
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

  Map<String, dynamic> toJson() => {
        'firebase_uid': firebaseUid,
        'author_name': authorName,
        'author_photo': authorPhoto,
        'content': content,
        'tags': tags,
      };

  static List<String> _parseList(dynamic val) {
    if (val == null) return [];
    if (val is List) return val.map((e) => e.toString()).toList();
    return [];
  }

  PostModel copyWith({
    int? likesCount,
    int? commentsCount,
    bool? isLiked,
  }) {
    return PostModel(
      id: id,
      firebaseUid: firebaseUid,
      authorName: authorName,
      authorPhoto: authorPhoto,
      content: content,
      tags: tags,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      createdAt: createdAt,
      isLiked: isLiked ?? this.isLiked,
    );
  }
}

// ── Providers ────────────────────────────────────────────────────────────────

final communityFeedProvider = StateNotifierProvider<CommunityFeedNotifier, AsyncValue<List<PostModel>>>((ref) {
  return CommunityFeedNotifier();
});

class CommunityFeedNotifier extends StateNotifier<AsyncValue<List<PostModel>>> {
  CommunityFeedNotifier() : super(const AsyncLoading()) {
    fetchPosts();
  }

  final _mockPosts = [
    PostModel(
      id: 'mock_1',
      firebaseUid: 'user_1',
      authorName: 'Marie Diallo',
      authorPhoto: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb',
      content: 'Je viens de soumettre ma candidature pour la bourse Eiffel en France ! Croisez les doigts pour moi 🤞 Des conseils pour l\'entretien de sélection ?',
      tags: const ['Eiffel', 'France', 'Master'],
      likesCount: 12,
      commentsCount: 3,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      isLiked: false,
    ),
    PostModel(
      id: 'mock_2',
      firebaseUid: 'user_2',
      authorName: 'Kofi Mensah',
      authorPhoto: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d',
      content: 'Est-ce que quelqu\'un prépare le test TOEFL ou IELTS en ce moment ? J\'ai besoin d\'un binôme pour pratiquer l\'oral.',
      tags: const ['TOEFL', 'IELTS', 'Langues'],
      likesCount: 8,
      commentsCount: 5,
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      isLiked: true,
    ),
    PostModel(
      id: 'mock_3',
      firebaseUid: 'system',
      authorName: 'Fly AI Guide',
      content: '🚀 Astuce du jour : Lors de la rédaction de votre lettre de motivation, concentrez-vous sur l\'impact de vos études de retour dans votre pays d\'origine. Les comités adorent ce point !',
      tags: const ['Conseils', 'Motivation', 'SOP'],
      likesCount: 24,
      commentsCount: 2,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      isLiked: false,
    ),
  ];

  Future<void> fetchPosts() async {
    final user = AuthService.currentUser;
    try {
      // 1. Fetch posts from Supabase
      final postsResponse = await SupabaseService.client
          .from('posts')
          .select()
          .order('created_at', ascending: false);

      final List<PostModel> posts = [];

      // 2. Fetch liked posts by current user to set isLiked flag
      List<String> likedPostIds = [];
      if (user != null) {
        final likesResponse = await SupabaseService.client
            .from('post_likes')
            .select('post_id')
            .eq('firebase_uid', user.uid);
        likedPostIds = (likesResponse as List).map((l) => l['post_id'].toString()).toList();
      }

      for (var p in (postsResponse as List)) {
        final postId = p['id'].toString();
        posts.add(PostModel.fromJson(p as Map<String, dynamic>, isLiked: likedPostIds.contains(postId)));
      }

      // If empty, load mock posts alongside
      if (posts.isEmpty) {
        state = AsyncValue.data(_mockPosts);
      } else {
        state = AsyncValue.data(posts);
      }
    } catch (e) {
      // Fallback to mock data if table does not exist or network failure
      state = AsyncValue.data(_mockPosts);
    }
  }

  Future<void> createPost(String content, List<String> tags) async {
    final user = AuthService.currentUser;
    if (user == null) return;

    final newPostLocal = PostModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      firebaseUid: user.uid,
      authorName: user.displayName ?? 'Scholar',
      authorPhoto: user.photoURL,
      content: content,
      tags: tags,
      createdAt: DateTime.now(),
      likesCount: 0,
      commentsCount: 0,
    );

    // Add locally immediately
    state.whenData((posts) {
      state = AsyncValue.data([newPostLocal, ...posts]);
    });

    try {
      // Attempt to save to Supabase
      await SupabaseService.client.from('posts').insert(newPostLocal.toJson());
      // Re-fetch to sync
      fetchPosts();
    } catch (_) {
      // Gracefully continue with local state
    }
  }

  Future<void> toggleLike(String postId) async {
    final user = AuthService.currentUser;
    if (user == null) return;

    // Toggle locally immediately
    state.whenData((posts) {
      final updated = posts.map((p) {
        if (p.id == postId) {
          final newLiked = !p.isLiked;
          final newCount = p.likesCount + (newLiked ? 1 : -1);
          return p.copyWith(isLiked: newLiked, likesCount: newCount);
        }
        return p;
      }).toList();
      state = AsyncValue.data(updated);
    });

    try {
      final postsList = state.value ?? [];
      final post = postsList.firstWhere((p) => p.id == postId);

      if (post.isLiked) {
        // Insert like
        await SupabaseService.client.from('post_likes').insert({
          'post_id': postId,
          'firebase_uid': user.uid,
        });
        // Increment post likes count
        await SupabaseService.client.rpc('increment_likes', params: {'post_id': postId});
      } else {
        // Delete like
        await SupabaseService.client
            .from('post_likes')
            .delete()
            .eq('post_id', postId)
            .eq('firebase_uid', user.uid);
        // Decrement post likes count
        await SupabaseService.client.rpc('decrement_likes', params: {'post_id': postId});
      }
    } catch (_) {
      // Silent error fallback (keeps local state)
    }
  }
}

// ── Screen UI ────────────────────────────────────────────────────────────────

class CommunityFeedScreen extends ConsumerStatefulWidget {
  const CommunityFeedScreen({super.key});

  @override
  ConsumerState<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends ConsumerState<CommunityFeedScreen> {
  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(communityFeedProvider);
    final isFr = ref.watch(localeProvider).languageCode == 'fr';
    final filters = isFr
        ? ['Tous', 'Questions', 'Partages', 'Conseils']
        : ['All', 'Questions', 'Shares', 'Tips'];

    final strings = isFr ? _FrenchStrings() : _EnglishStrings();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(strings.title, style: AppTextStyles.headlineSmall),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(communityFeedProvider.notifier).fetchPosts(),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(communityFeedProvider.notifier).fetchPosts(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Create Post Prompt ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildCreatePostBar(strings),
            ),

            // ── Filter Chips ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                height: 50,
                padding: const EdgeInsets.only(left: 24, bottom: 12),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: filters.length,
                  itemBuilder: (context, i) {
                    final isSelected = _selectedFilter.toLowerCase() == filters[i].toLowerCase() ||
                        (_selectedFilter == 'All' && filters[i] == 'Tous') ||
                        (_selectedFilter == 'Tous' && filters[i] == 'All');
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(filters[i]),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedFilter = filters[i];
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
            ),

            // ── Posts List ──────────────────────────────────────────────────
            postsAsync.when(
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              ),
              error: (err, _) => SliverFillRemaining(
                child: Center(
                  child: Text(strings.errorLoading, style: AppTextStyles.bodyMedium),
                ),
              ),
              data: (posts) {
                // Apply filter
                final filteredPosts = posts.where((p) {
                  if (_selectedFilter == 'All' || _selectedFilter == 'Tous') return true;
                  if (_selectedFilter == 'Questions' && p.content.contains('?')) return true;
                  if (_selectedFilter == 'Conseils' || _selectedFilter == 'Tips') {
                    return p.tags.any((t) => t.toLowerCase().contains('conseil') || t.toLowerCase().contains('tip'));
                  }
                  return p.tags.any((t) => t.toLowerCase() == _selectedFilter.toLowerCase());
                }).toList();

                if (filteredPosts.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.feed_outlined, size: 64, color: AppColors.glassBorder),
                            const SizedBox(height: 16),
                            Text(strings.noPosts, style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final post = filteredPosts[index];
                      return _PostCard(post: post, strings: strings);
                    },
                    childCount: filteredPosts.length,
                  ),
                );
              },
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _showCreatePostModal(context, strings),
        child: const Icon(Icons.create_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildCreatePostBar(_Strings strings) {
    final user = AuthService.currentUser;
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
            child: user?.photoURL == null
                ? Text(
                    user?.displayName != null && user!.displayName!.isNotEmpty
                        ? user.displayName![0].toUpperCase()
                        : 'S',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: GestureDetector(
              onTap: () => _showCreatePostModal(context, strings),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Text(
                  strings.whatsOnYourMind,
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreatePostModal(BuildContext context, _Strings strings) {
    final contentCtrl = TextEditingController();
    final tagsCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 24,
            left: 24,
            right: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(strings.createPost, style: AppTextStyles.headlineSmall),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: contentCtrl,
                maxLines: 5,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: strings.whatsOnYourMind,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.glassBorder),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: tagsCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: strings.tagsHint,
                  prefixIcon: const Icon(Icons.local_offer_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.glassBorder),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  final content = contentCtrl.text.trim();
                  if (content.isNotEmpty) {
                    final tags = tagsCtrl.text
                        .split(',')
                        .map((t) => t.trim().replaceAll('#', ''))
                        .where((t) => t.isNotEmpty)
                        .toList();
                    ref.read(communityFeedProvider.notifier).createPost(content, tags);
                    Navigator.pop(context);
                  }
                },
                child: Text(strings.publish),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

class _PostCard extends ConsumerWidget {
  final PostModel post;
  final _Strings strings;

  const _PostCard({required this.post, required this.strings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String timeAgo = _formatTimeAgo(post.createdAt, ref.watch(localeProvider).languageCode);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar + Author + Time
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                backgroundImage: post.authorPhoto != null ? NetworkImage(post.authorPhoto!) : null,
                child: post.authorPhoto == null
                    ? Text(
                        post.authorName.isNotEmpty ? post.authorName[0].toUpperCase() : 'S',
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.authorName,
                      style: AppTextStyles.titleLarge,
                    ),
                    Text(
                      timeAgo,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Content text
          Text(
            post.content,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),

          // HashTags
          if (post.tags.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: post.tags.map((tag) {
                return Text(
                  '#$tag',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
          ],

          // Footer Divider
          Divider(color: AppColors.glassBorder, height: 1),
          const SizedBox(height: 10),

          // Actions Row: Like + Comment + Share
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ActionButton(
                icon: post.isLiked ? Icons.favorite : Icons.favorite_border_rounded,
                color: post.isLiked ? AppColors.error : AppColors.textSecondary,
                label: '${post.likesCount}',
                onTap: () {
                  ref.read(communityFeedProvider.notifier).toggleLike(post.id);
                },
              ),
              _ActionButton(
                icon: Icons.chat_bubble_outline_rounded,
                color: AppColors.textSecondary,
                label: '${post.commentsCount}',
                onTap: () {},
              ),
              _ActionButton(
                icon: Icons.send_outlined,
                color: AppColors.textSecondary,
                label: '',
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime, String lang) {
    final diff = DateTime.now().difference(dateTime);
    if (lang == 'fr') {
      if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
      if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
      return DateFormat('dd MMM yyyy').format(dateTime);
    } else {
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return DateFormat('MMM dd, yyyy').format(dateTime);
    }
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Localization Strings ─────────────────────────────────────────────────────

abstract class _Strings {
  String get title;
  String get errorLoading;
  String get noPosts;
  String get whatsOnYourMind;
  String get createPost;
  String get tagsHint;
  String get publish;
}

class _FrenchStrings implements _Strings {
  @override
  String get title => 'Communauté 🌐';
  @override
  String get errorLoading => 'Erreur de chargement du flux.';
  @override
  String get noPosts => 'Aucune publication pour le moment.\nSoyez le premier à partager !';
  @override
  String get whatsOnYourMind => 'Partagez quelque chose avec les boursiers...';
  @override
  String get createPost => 'Créer une publication';
  @override
  String get tagsHint => 'Tags (séparés par des virgules, ex: Eiffel, DAAD)';
  @override
  String get publish => 'Publier';
}

class _EnglishStrings implements _Strings {
  @override
  String get title => 'Community Feed 🌐';
  @override
  String get errorLoading => 'Error loading community feed.';
  @override
  String get noPosts => 'No posts in this feed yet.\nBe the first to share something!';
  @override
  String get whatsOnYourMind => 'Share something with other scholars...';
  @override
  String get createPost => 'Create Post';
  @override
  String get tagsHint => 'Tags (comma separated, e.g. Eiffel, DAAD)';
  @override
  String get publish => 'Publish';
}
