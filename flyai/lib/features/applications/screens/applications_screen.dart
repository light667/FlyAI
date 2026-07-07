import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../models/application_model.dart';
import '../providers/application_provider.dart';

class ApplicationsScreen extends ConsumerStatefulWidget {
  const ApplicationsScreen({super.key});
  @override
  ConsumerState<ApplicationsScreen> createState() =>
      _ApplicationsScreenState();
}

class _ApplicationsScreenState extends ConsumerState<ApplicationsScreen> {
  int _tabIndex = 0;
  final _tabs = ['Tout', 'Brouillon', 'Soumis', 'Accepté'];

  List<ApplicationModel> _filtered(List<ApplicationModel> apps) {
    if (_tabIndex == 0) return apps;
    final statusKey = ['', 'draft', 'submitted', 'accepted'][_tabIndex];
    return apps.where((a) => a.status == statusKey).toList();
  }

  @override
  Widget build(BuildContext context) {
    final appsAsync = ref.watch(applicationNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: appsAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text('Erreur de chargement', style: AppTextStyles.bodyMedium),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => ref.refresh(applicationNotifierProvider),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (apps) {
          final filtered = _filtered(apps);
          return CustomScrollView(
            slivers: [
              // ── Header ────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 64, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Candidatures',
                        style: AppTextStyles.displayMedium
                            .copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Suis ta progression vers chaque bourse',
                        style: AppTextStyles.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      // Summary chips
                      if (apps.isNotEmpty)
                        Row(
                          children: [
                            _SummaryChip(
                              label:
                                  '${apps.length} total',
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            _SummaryChip(
                              label:
                                  '${apps.where((a) => a.status == "submitted").length} soumis',
                              color: AppColors.secondary,
                            ),
                            const SizedBox(width: 8),
                            _SummaryChip(
                              label:
                                  '${apps.where((a) => a.status == "accepted").length} accepté',
                              color: AppColors.success,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),

              // ── Sticky tab bar ────────────────────────────────────────
              // Uses SliverPersistentHeader INSIDE CustomScrollView (not NestedScrollView)
              // → no SliverGeometry layoutExtent conflict.
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(
                  tabs: _tabs,
                  tabIndex: _tabIndex,
                  onTap: (i) => setState(() => _tabIndex = i),
                ),
              ),

              // ── Application cards or empty state ──────────────────────
              if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(status: _tabs[_tabIndex]),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) =>
                          _ApplicationCard(application: filtered[i]),
                      childCount: filtered.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── Summary chip ───────────────────────────────────────────────────────────

class _SummaryChip extends StatelessWidget {
  final String label;
  final Color color;
  const _SummaryChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ── Tab Bar Delegate ───────────────────────────────────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final List<String> tabs;
  final int tabIndex;
  final void Function(int) onTap;

  const _TabBarDelegate({
    required this.tabs,
    required this.tabIndex,
    required this.onTap,
  });

  @override
  double get minExtent => 52;
  @override
  double get maxExtent => 52;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(tabs.length, (i) {
            final active = i == tabIndex;
            return GestureDetector(
              onTap: () => onTap(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : AppColors.card,
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(
                    color:
                        active ? AppColors.primary : AppColors.glassBorder,
                  ),
                ),
                child: Text(
                  tabs[i],
                  style: TextStyle(
                    color: active ? Colors.white : AppColors.textSecondary,
                    fontWeight:
                        active ? FontWeight.w700 : FontWeight.w500,
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
  bool shouldRebuild(covariant _TabBarDelegate old) =>
      old.tabIndex != tabIndex;
}

// ── Application Card ───────────────────────────────────────────────────────

class _ApplicationCard extends ConsumerStatefulWidget {
  final ApplicationModel application;
  const _ApplicationCard({required this.application});
  @override
  ConsumerState<_ApplicationCard> createState() => _ApplicationCardState();
}

class _ApplicationCardState extends ConsumerState<_ApplicationCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final app = widget.application;
    final title =
        app.scholarship?.title ?? 'Candidature';
    final university =
        app.scholarship?.university ?? 'Institution inconnue';
    final done = app.checklist.values.where((v) => v).length;
    final total = app.checklist.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.glassBorder),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // Card header
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Progress ring
                SizedBox(
                  width: 54,
                  height: 54,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: total > 0 ? done / total : 0,
                        backgroundColor: AppColors.glassBorder,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          app.progress == 100
                              ? AppColors.success
                              : AppColors.primary,
                        ),
                        strokeWidth: 5,
                        strokeCap: StrokeCap.round,
                      ),
                      Text(
                        '${app.progress}%',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: app.progress == 100
                              ? AppColors.success
                              : AppColors.primary,
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
                              style: AppTextStyles.titleMedium
                                  .copyWith(fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _StatusBadge(status: app.status),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(university,
                          style: AppTextStyles.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      Text(
                        '$done / $total documents prêts',
                        style: AppTextStyles.caption.copyWith(
                          color: done == total
                              ? AppColors.success
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Expandable checklist
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            child: _expanded
                ? Column(
                    children: [
                      Divider(height: 1, color: AppColors.glassBorder),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                        child: Column(
                          children:
                              app.checklist.entries.map((entry) {
                            final isDone = entry.value;
                            return ListTile(
                              dense: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              leading: Checkbox(
                                value: isDone,
                                activeColor: AppColors.success,
                                checkColor: Colors.white,
                                side: BorderSide(
                                    color: AppColors.glassBorder,
                                    width: 1.5),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4)),
                                onChanged: (val) {
                                  if (val != null) {
                                    ref
                                        .read(applicationNotifierProvider
                                            .notifier)
                                        .toggleChecklistItem(
                                            app.id, entry.key, val);
                                  }
                                },
                              ),
                              title: Text(
                                entry.key,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: isDone
                                      ? AppColors.textSecondary
                                      : AppColors.textPrimary,
                                  decoration: isDone
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              trailing: !isDone &&
                                      (entry.key == 'Motivation Letter' ||
                                          entry.key == 'CV')
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.secondary
                                            .withValues(alpha: 0.15),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.auto_awesome,
                                              size: 11,
                                              color: AppColors.secondary),
                                          const SizedBox(width: 4),
                                          Text('IA',
                                              style: TextStyle(
                                                  color: AppColors.secondary,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700)),
                                        ],
                                      ),
                                    )
                                  : null,
                            );
                          }).toList(),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (app.status == 'draft')
                              TextButton(
                                onPressed: () => ref
                                    .read(applicationNotifierProvider.notifier)
                                    .updateStatus(app.id, 'submitted'),
                                child: const Text('Soumettre',
                                    style: TextStyle(
                                        color: AppColors.success,
                                        fontWeight: FontWeight.bold)),
                              ),
                            TextButton(
                              onPressed: () => _showCancelDialog(context),
                              child: const Text('Supprimer',
                                  style:
                                      TextStyle(color: AppColors.error)),
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
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(color: AppColors.glassBorder)),
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(22)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _expanded ? 'Réduire' : 'Voir la liste',
                    style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
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

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer ?'),
        content: Text(
          'Arrêter le suivi de cette candidature ?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annuler',
                  style: TextStyle(color: AppColors.textSecondary))),
          TextButton(
            onPressed: () {
              ref
                  .read(applicationNotifierProvider.notifier)
                  .cancelApplication(widget.application.id);
              Navigator.pop(context);
            },
            child: const Text('Supprimer',
                style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold)),
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
      'submitted' => ('Soumis', AppColors.primary.withValues(alpha: 0.15),
          AppColors.primary),
      'accepted' => ('Accepté ✓',
          AppColors.success.withValues(alpha: 0.15), AppColors.success),
      'rejected' => ('Refusé',
          AppColors.error.withValues(alpha: 0.15), AppColors.error),
      _ => ('Brouillon', AppColors.glassBorder, AppColors.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
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
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: AppColors.glassBorder),
              child: Icon(Icons.assignment_outlined,
                  size: 40, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            Text('Aucune candidature — $status',
                style: AppTextStyles.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Accepte une bourse dans Découvrir pour commencer.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
