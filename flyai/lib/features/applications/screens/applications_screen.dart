import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../models/application_model.dart';
import '../providers/application_provider.dart';

class ApplicationsScreen extends ConsumerStatefulWidget {
  const ApplicationsScreen({super.key});
  @override
  ConsumerState<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends ConsumerState<ApplicationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _tabs = ['All', 'Draft', 'Submitted', 'Accepted'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appsAsync = ref.watch(applicationNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, inner) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 64, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Applications',
                    style: AppTextStyles.displayMedium.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Track your scholarship journey',
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabHeaderDelegate(
              tabs: _tabs,
              controller: _tabCtrl,
            ),
          ),
        ],
        body: appsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (err, _) => _ErrorView(onRetry: () => ref.refresh(applicationNotifierProvider)),
          data: (apps) {
            final filtered = _tabCtrl.index == 0
                ? apps
                : apps.where((a) => a.status == _tabs[_tabCtrl.index].toLowerCase()).toList();

            if (filtered.isEmpty) return _EmptyState(status: _tabs[_tabCtrl.index]);

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
              itemCount: filtered.length,
              itemBuilder: (context, i) => _ApplicationCard(application: filtered[i]),
            );
          },
        ),
      ),
    );
  }
}

// ── Tab Header ─────────────────────────────────────────────────────────────

class _TabHeaderDelegate extends SliverPersistentHeaderDelegate {
  final List<String> tabs;
  final TabController controller;
  const _TabHeaderDelegate({required this.tabs, required this.controller});

  @override
  double get minExtent => 56;
  @override
  double get maxExtent => 56;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(tabs.length, (i) {
            final isActive = controller.index == i;
            return GestureDetector(
              onTap: () => controller.animateTo(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : AppColors.card,
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(
                    color: isActive ? AppColors.primary : AppColors.glassBorder,
                  ),
                ),
                child: Text(
                  tabs[i],
                  style: TextStyle(
                    color: isActive ? Colors.white : AppColors.textSecondary,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TabHeaderDelegate oldDelegate) => true;
}

// ── Application Card ───────────────────────────────────────────────────────

class _ApplicationCard extends ConsumerStatefulWidget {
  final ApplicationModel application;
  const _ApplicationCard({required this.application});
  @override
  ConsumerState<_ApplicationCard> createState() => _ApplicationCardState();
}

class _ApplicationCardState extends ConsumerState<_ApplicationCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final app = widget.application;
    final title = app.scholarship?.title ?? 'Scholarship Application';
    final university = app.scholarship?.university ?? 'Unknown Institution';
    final doneCount = app.checklist.values.where((v) => v).length;
    final total = app.checklist.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.glassBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // Card Header
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Progress Ring
                SizedBox(
                  width: 54,
                  height: 54,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: total > 0 ? doneCount / total : 0,
                        backgroundColor: AppColors.glassBorder,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          app.progress == 100 ? AppColors.success : AppColors.primary,
                        ),
                        strokeWidth: 5,
                        strokeCap: StrokeCap.round,
                      ),
                      Text(
                        '${app.progress}%',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: app.progress == 100 ? AppColors.success : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _StatusBadge(status: app.status),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(university, style: AppTextStyles.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 10),
                      Text(
                        '$doneCount / $total documents ready',
                        style: AppTextStyles.caption.copyWith(
                          color: doneCount == total ? AppColors.success : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Expandable Checklist
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            child: _isExpanded
                ? Column(
                    children: [
                      Divider(height: 1, color: AppColors.glassBorder),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Column(
                          children: app.checklist.entries.map((entry) {
                            final isDone = entry.value;
                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                              leading: Checkbox(
                                value: isDone,
                                activeColor: AppColors.success,
                                checkColor: Colors.white,
                                side: BorderSide(color: AppColors.glassBorder, width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                onChanged: (val) {
                                  if (val != null) {
                                    ref.read(applicationNotifierProvider.notifier)
                                        .toggleChecklistItem(app.id, entry.key, val);
                                  }
                                },
                              ),
                              title: Text(
                                entry.key,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: isDone ? AppColors.textSecondary : AppColors.textPrimary,
                                  decoration: isDone ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              trailing: !isDone && (entry.key == 'Motivation Letter' || entry.key == 'CV')
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.secondary.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.auto_awesome, size: 11, color: AppColors.secondary),
                                          const SizedBox(width: 4),
                                          Text('AI Write', style: TextStyle(color: AppColors.secondary, fontSize: 11, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    )
                                  : null,
                            );
                          }).toList(),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (app.status == 'draft')
                              TextButton(
                                onPressed: () => ref.read(applicationNotifierProvider.notifier)
                                    .updateStatus(app.id, 'submitted'),
                                child: const Text('Submit', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
                              ),
                            TextButton(
                              onPressed: () => _showCancelDialog(context, app.id),
                              child: const Text('Remove', style: TextStyle(color: AppColors.error)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),

          // Expand toggle
          GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.glassBorder)),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isExpanded ? 'Collapse' : 'View checklist',
                    style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove tracking?'),
        content: Text('Stop tracking this application?', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
          TextButton(
            onPressed: () {
              ref.read(applicationNotifierProvider.notifier).cancelApplication(id);
              Navigator.pop(context);
            },
            child: const Text('Remove', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      'submitted' => ('Submitted', AppColors.primary.withOpacity(0.15), AppColors.primary),
      'accepted' => ('Accepted ✓', AppColors.success.withOpacity(0.15), AppColors.success),
      'rejected' => ('Rejected', AppColors.error.withOpacity(0.15), AppColors.error),
      _ => ('Draft', AppColors.glassBorder, AppColors.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String status;
  const _EmptyState({required this.status});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.glassBorder),
              child: Icon(Icons.assignment_outlined, size: 40, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            Text('No $status applications', style: AppTextStyles.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Swipe right on scholarships or tap "Start Application" to begin tracking.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
          const SizedBox(height: 16),
          Text('Failed to load applications', style: AppTextStyles.bodyMedium),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
