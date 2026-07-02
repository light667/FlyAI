import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_router.dart';
import '../providers/profile_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../../scholarships/providers/scholarship_provider.dart';
import '../../scholarships/models/scholarship_model.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileNotifierProvider);
    final statsAsync = ref.watch(dashboardStatsProvider);
    final likedAsync = ref.watch(likedScholarshipsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) => _ProfileError(),
        data: (profile) {
          if (profile == null) return _ProfileError();
          return NestedScrollView(
            headerSliverBuilder: (context, inner) => [
              // ── Cover + Avatar ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Cover gradient
                    Container(
                      height: 160,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary,
                            const Color(0xFF7C3AED),
                            AppColors.secondary.withOpacity(0.8),
                          ],
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(painter: _WavePainter()),
                          ),
                          // Settings button
                          Positioned(
                            top: 52,
                            right: 20,
                            child: GestureDetector(
                              onTap: () => context.push(AppRoutes.settings),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.settings_outlined, color: Colors.white, size: 20),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Avatar
                    Positioned(
                      bottom: -44,
                      left: 24,
                      child: Stack(
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.background, width: 4),
                              gradient: const LinearGradient(
                                colors: [AppColors.primary, Color(0xFF7C3AED)],
                              ),
                            ),
                            child: profile.photoUrl != null
                                ? ClipOval(
                                    child: CachedNetworkImage(
                                      imageUrl: profile.photoUrl!,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      profile.fullName.isNotEmpty ? profile.fullName[0].toUpperCase() : '?',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 32,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 160),
                  ],
                ),
              ),

              // ── Profile Info ────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 56, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile.fullName,
                                  style: AppTextStyles.headlineLarge.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 3),
                                if (profile.university.isNotEmpty)
                                  Text(
                                    '${profile.fieldOfStudy} · ${profile.university}',
                                    style: AppTextStyles.bodyMedium,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.location_on_rounded, size: 13, color: AppColors.textSecondary),
                                    const SizedBox(width: 3),
                                    Text(profile.country, style: AppTextStyles.bodySmall),
                                    const SizedBox(width: 10),
                                    if (profile.educationLevel.isNotEmpty) ...[
                                      Icon(Icons.school_outlined, size: 13, color: AppColors.textSecondary),
                                      const SizedBox(width: 3),
                                      Text(profile.educationLevel, style: AppTextStyles.bodySmall),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => context.push(AppRoutes.profileSetup),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.primary, width: 1.5),
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: Text(
                                'Edit',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Stats row
                      statsAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (stats) => Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.glassBorder),
                          ),
                          child: Row(
                            children: [
                              _StatItem(value: '${stats.totalMatches}', label: 'Matches'),
                              _Divider(),
                              _StatItem(value: '${stats.activeApplications}', label: 'Applications'),
                              _Divider(),
                              _StatItem(
                                value: '${stats.avgCompatibility.round()}%',
                                label: 'Avg Score',
                                color: AppColors.success,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // ── Tab Bar ─────────────────────────────────────────────────
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickyTabBar(controller: _tabCtrl),
              ),
            ],

            // ── Tab Bodies ─────────────────────────────────────────────────
            body: TabBarView(
              controller: _tabCtrl,
              children: [
                // About tab
                _AboutTab(profile: profile),

                // Saved tab
                likedAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (scholarships) => _SavedTab(scholarships: scholarships),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Sticky Tab Bar ─────────────────────────────────────────────────────────

class _StickyTabBar extends SliverPersistentHeaderDelegate {
  final TabController controller;
  const _StickyTabBar({required this.controller});

  @override
  double get minExtent => 52;
  @override
  double get maxExtent => 52;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    return Container(
      color: AppColors.background,
      child: TabBar(
        controller: controller,
        tabs: const [Tab(text: 'About'), Tab(text: 'Saved')],
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary,
        indicatorSize: TabBarIndicatorSize.label,
        indicatorWeight: 3,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickyTabBar old) => false;
}

// ── About Tab ──────────────────────────────────────────────────────────────

class _AboutTab extends StatelessWidget {
  final dynamic profile;
  const _AboutTab({required this.profile});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      children: [
        if (profile.academicGoals.isNotEmpty) ...[
          _SectionTitle('Goals'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Text(
              profile.academicGoals,
              style: AppTextStyles.bodyMedium.copyWith(height: 1.6),
            ),
          ),
          const SizedBox(height: 20),
        ],

        _SectionTitle('Academic'),
        _InfoGrid([
          _InfoItem(Icons.school_outlined, 'Level', profile.educationLevel),
          _InfoItem(Icons.menu_book_outlined, 'Field', profile.fieldOfStudy),
          if (profile.gpa > 0)
            _InfoItem(Icons.grade_outlined, 'GPA', profile.gpa.toStringAsFixed(2)),
          _InfoItem(Icons.location_city_rounded, 'University', profile.university),
        ]),
        const SizedBox(height: 20),

        _SectionTitle('Languages'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (profile.englishLevel.isNotEmpty)
              _LangChip('English', profile.englishLevel, AppColors.primary),
            if (profile.frenchLevel.isNotEmpty)
              _LangChip('French', profile.frenchLevel, const Color(0xFF7C3AED)),
            ...profile.otherLanguages.entries.map<Widget>(
              (e) => _LangChip(e.key, e.value, AppColors.secondary),
            ),
          ],
        ),
        const SizedBox(height: 20),

        if (profile.targetCountries.isNotEmpty) ...[
          _SectionTitle('Target Countries'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: profile.targetCountries
                .map<Widget>((c) => _TagChip(c.toString()))
                .toList(),
          ),
          const SizedBox(height: 20),
        ],

        if (profile.targetFields.isNotEmpty) ...[
          _SectionTitle('Target Fields'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: profile.targetFields
                .map<Widget>((f) => _TagChip(f.toString()))
                .toList(),
          ),
        ],
      ],
    );
  }
}

// ── Saved Tab ──────────────────────────────────────────────────────────────

class _SavedTab extends StatelessWidget {
  final List<ScholarshipModel> scholarships;
  const _SavedTab({required this.scholarships});

  @override
  Widget build(BuildContext context) {
    if (scholarships.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_outline_rounded, size: 56, color: AppColors.glassBorder),
            const SizedBox(height: 16),
            Text('No saved scholarships', style: AppTextStyles.headlineSmall),
            const SizedBox(height: 8),
            Text('Swipe right to save scholarships here.', style: AppTextStyles.bodyMedium),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: scholarships.length,
      itemBuilder: (context, i) => _SavedCard(scholarship: scholarships[i]),
    );
  }
}

class _SavedCard extends StatelessWidget {
  final ScholarshipModel scholarship;
  const _SavedCard({required this.scholarship});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: SizedBox(
              height: 90,
              width: double.infinity,
              child: scholarship.imageUrl != null
                  ? CachedNetworkImage(imageUrl: scholarship.imageUrl!, fit: BoxFit.cover)
                  : Container(
                      color: AppColors.primary.withOpacity(0.15),
                      child: const Center(child: Icon(Icons.school_rounded, color: AppColors.primary, size: 32)),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(scholarship.title, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(scholarship.country, style: AppTextStyles.caption),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${scholarship.compatibilityScore}% match',
                    style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w700),
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

// ── Helpers ────────────────────────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final Color? color;
  const _StatItem({required this.value, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color ?? AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 40, color: AppColors.glassBorder);
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: AppColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  final List<_InfoItem> items;
  const _InfoGrid(this.items);
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 3.2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: items,
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoItem(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: AppTextStyles.caption.copyWith(fontSize: 10)),
                Text(value, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LangChip extends StatelessWidget {
  final String lang;
  final String level;
  final Color color;
  const _LangChip(this.lang, this.level, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(lang, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(width: 6),
          Text('· $level', style: TextStyle(color: color.withOpacity(0.7), fontSize: 12)),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String text;
  const _TagChip(this.text);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Text(text, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
    );
  }
}

class _ProfileError extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off_outlined, size: 56, color: AppColors.glassBorder),
          const SizedBox(height: 16),
          Text('Profile not found', style: AppTextStyles.headlineSmall),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.push(AppRoutes.profileSetup),
            child: const Text('Create Profile'),
          ),
        ],
      ),
    );
  }
}

// ── Wave Painter for cover ─────────────────────────────────────────────────

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height * 0.6)
      ..quadraticBezierTo(size.width * 0.25, size.height * 0.4, size.width * 0.5, size.height * 0.65)
      ..quadraticBezierTo(size.width * 0.75, size.height * 0.9, size.width, size.height * 0.55)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, paint);

    final path2 = Path()
      ..moveTo(0, size.height * 0.8)
      ..quadraticBezierTo(size.width * 0.3, size.height * 0.6, size.width * 0.6, size.height * 0.8)
      ..quadraticBezierTo(size.width * 0.8, size.height, size.width, size.height * 0.75)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path2, Paint()..color = Colors.white.withOpacity(0.04));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
