import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../models/application_model.dart';
import '../providers/application_provider.dart';

class ApplicationsScreen extends ConsumerWidget {
  const ApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appsAsync = ref.watch(applicationNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('My Applications 📁', style: AppTextStyles.headlineSmall),
      ),
      body: appsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text('Failed to load applications', style: AppTextStyles.bodyMedium),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => ref.refresh(applicationNotifierProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (apps) {
          if (apps.isEmpty) {
            return const _EmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            itemCount: apps.length,
            itemBuilder: (context, index) {
              return _ApplicationCard(application: apps[index]);
            },
          );
        },
      ),
    );
  }
}

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
    final scholarship = app.scholarship;
    final title = scholarship?.title ?? "Scholarship Application";
    final university = scholarship?.university ?? "Unknown Institution";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          // Header info
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusBadge(status: app.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  university,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),

                // Progress Bar
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: app.progress / 100,
                          minHeight: 8,
                          backgroundColor: AppColors.glassBorder,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            app.progress == 100 ? AppColors.success : AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${app.progress}%',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: app.progress == 100 ? AppColors.success : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Divider(height: 1, color: AppColors.glassBorder),

          // Expandable checklist
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              title: Text(
                'Document Checklist (${app.checklist.values.where((v) => v).length}/${app.checklist.length})',
                style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
              ),
              trailing: Icon(
                _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                color: AppColors.textSecondary,
              ),
              onExpansionChanged: (expanded) => setState(() => _isExpanded = expanded),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(
                    children: app.checklist.entries.map((entry) {
                      final item = entry.key;
                      final isDone = entry.value;

                      return ListTile(
                        leading: Checkbox(
                          value: isDone,
                          activeColor: AppColors.success,
                          checkColor: Colors.white,
                          side: BorderSide(color: AppColors.glassBorder, width: 1.5),
                          onChanged: (val) {
                            if (val != null) {
                              ref
                                  .read(applicationNotifierProvider.notifier)
                                  .toggleChecklistItem(app.id, item, val);
                            }
                          },
                        ),
                        title: Text(
                          item,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: isDone ? AppColors.textSecondary : AppColors.textPrimary,
                            decoration: isDone ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        trailing: (item == 'Motivation Letter' || item == 'CV') && !isDone
                            ? TextButton.icon(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () {
                                  // In real app, navigate user to AI tab with custom instructions.
                                  // For presentation, show modal notification:
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Deep linking to Fly Assistant for writing your $item... ⚡',
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.auto_awesome, size: 12, color: AppColors.secondary),
                                label: Text(
                                  'AI Write',
                                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondary),
                                ),
                              )
                            : null,
                      );
                    }).toList(),
                  ),
                ),
                // Actions Footer
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (app.status == 'draft')
                        TextButton(
                          onPressed: () {
                            ref
                                .read(applicationNotifierProvider.notifier)
                                .updateStatus(app.id, 'submitted');
                          },
                          child: const Text(
                            'Submit Application',
                            style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold),
                          ),
                        ),
                      TextButton(
                        onPressed: () {
                          _showCancelDialog(context, ref, app.id);
                        },
                        child: const Text(
                          'Cancel Application',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Cancel Tracking?'),
        content: Text(
          'Are you sure you want to stop tracking this scholarship application? This cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('No, keep it', style: TextStyle(color: AppColors.textPrimary)),
          ),
          TextButton(
            onPressed: () {
              ref.read(applicationNotifierProvider.notifier).cancelApplication(id);
              Navigator.pop(context);
            },
            child: const Text('Yes, remove', style: TextStyle(color: AppColors.error)),
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
      'submitted' => ('Submitted', AppColors.primary.withOpacity(0.2), AppColors.primary),
      'accepted' => ('Accepted 🎉', AppColors.success.withOpacity(0.2), AppColors.success),
      'rejected' => ('Rejected', AppColors.error.withOpacity(0.2), AppColors.error),
      _ => ('Draft', AppColors.glassBorder, AppColors.textSecondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 72,
              color: AppColors.glassBorder,
            ),
            const SizedBox(height: 24),
            Text(
              'No active applications',
              style: AppTextStyles.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Swipe right or select "Start Application" in details to track documents.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
