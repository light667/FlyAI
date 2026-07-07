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

class _ApplicationsScreenState extends ConsumerState<ApplicationsScreen> {
  int _tabIndex = 0;
  final _tabs = ['Tout', 'Brouillon', 'Soumis', 'Accepté'];

  @override
  Widget build(BuildContext context) {
    final appsAsync = ref.watch(applicationNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      // Column-based layout: header (fixed) + tab strip (fixed) + list (scrollable)
      // No CustomScrollView, no SliverPersistentHeader → no SliverGeometry conflict.
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Fixed header ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Candidatures',
                      style: AppTextStyles.displayMedium
                          .copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text('Suis ta progression vers chaque bourse',
                      style: AppTextStyles.bodyMedium),
                ],
              ),
            ),

            // ── Fixed tab strip ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(_tabs.length, (i) {
                    final active = i == _tabIndex;
                    return GestureDetector(
                      onTap: () => setState(() => _tabIndex = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color: active ? AppColors.primary : AppColors.card,
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(
                            color: active
                                ? AppColors.primary
                                : AppColors.glassBorder,
                          ),
                        ),
                        child: Text(_tabs[i],
                            style: TextStyle(
                              color: active
                                  ? Colors.white
                                  : AppColors.textSecondary,
                              fontWeight: active
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: 13,
                            )),
                      ),
                    );
                  }),
                ),
              ),
            ),
            Divider(height: 1, color: AppColors.glassBorder),

            // ── Scrollable content ─────────────────────────────────────
            Expanded(
              child: appsAsync.when(
                loading: () => const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.primary)),
                error: (_, __) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 48, color: AppColors.error),
                      const SizedBox(height: 12),
                      Text('Erreur de chargement',
                          style: AppTextStyles.bodyMedium),
                      TextButton(
                        onPressed: () =>
                            ref.refresh(applicationNotifierProvider),
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
                data: (apps) {
                  final filtered = _filter(apps);
                  if (filtered.isEmpty) {
                    return _EmptyState(status: _tabs[_tabIndex]);
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) =>
                        _ApplicationCard(application: filtered[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<ApplicationModel> _filter(List<ApplicationModel> apps) {
    if (_tabIndex == 0) return apps;
    final key =
        ['', 'draft', 'submitted', 'accepted'][_tabIndex];
    return apps.where((a) => a.status == key).toList();
  }
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
    final title = app.scholarship?.title ?? 'Candidature';
    final university = app.scholarship?.university ?? '';
    final done = app.checklist.values.where((v) => v).length;
    final total = app.checklist.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Progress ring
                SizedBox(
                  width: 52,
                  height: 52,
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
                        strokeWidth: 4.5,
                        strokeCap: StrokeCap.round,
                      ),
                      Text('${app.progress}%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: app.progress == 100
                                ? AppColors.success
                                : AppColors.primary,
                          )),
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
                            child: Text(title,
                                style: AppTextStyles.titleMedium
                                    .copyWith(fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          _StatusBadge(status: app.status),
                        ],
                      ),
                      if (university.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(university,
                            style: AppTextStyles.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                      const SizedBox(height: 6),
                      Text('$done / $total documents prêts',
                          style: AppTextStyles.caption.copyWith(
                            color: done == total
                                ? AppColors.success
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),

          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            child: _expanded
                ? Column(children: [
                    Divider(height: 1, color: AppColors.glassBorder),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
                      child: Column(
                        children:
                            app.checklist.entries.map((entry) {
                          return CheckboxListTile(
                            dense: true,
                            value: entry.value,
                            activeColor: AppColors.success,
                            checkColor: Colors.white,
                            title: Text(entry.key,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: entry.value
                                      ? AppColors.textSecondary
                                      : AppColors.textPrimary,
                                  decoration: entry.value
                                      ? TextDecoration.lineThrough
                                      : null,
                                )),
                            onChanged: (val) {
                              if (val != null) {
                                ref
                                    .read(applicationNotifierProvider
                                        .notifier)
                                    .toggleChecklistItem(
                                        app.id, entry.key, val);
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (app.status == 'draft')
                            TextButton(
                              onPressed: () => ref
                                  .read(applicationNotifierProvider
                                      .notifier)
                                  .updateStatus(app.id, 'submitted'),
                              child: const Text('Soumettre',
                                  style: TextStyle(
                                      color: AppColors.success,
                                      fontWeight: FontWeight.bold)),
                            ),
                          TextButton(
                            onPressed: () => _confirmDelete(context),
                            child: const Text('Supprimer',
                                style:
                                    TextStyle(color: AppColors.error)),
                          ),
                        ],
                      ),
                    ),
                  ])
                : const SizedBox.shrink(),
          ),

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
                    _expanded ? 'Réduire' : 'Voir la checklist',
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

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer ?'),
        content: Text('Arrêter le suivi de cette candidature ?',
            style: TextStyle(color: AppColors.textSecondary)),
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
      'submitted' => ('Soumis',
          AppColors.primary.withValues(alpha: 0.15), AppColors.primary),
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
  Widget build(BuildContext context) => Center(
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
                    color: AppColors.glassBorder),
                child: Icon(Icons.assignment_outlined,
                    size: 40, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              Text('Aucune candidature',
                  style: AppTextStyles.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Accepte une bourse dans Découvrir\npour commencer ton suivi.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium,
              ),
            ],
          ),
        ),
      );
}