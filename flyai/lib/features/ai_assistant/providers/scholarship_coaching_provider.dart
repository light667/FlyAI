import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../scholarships/models/scholarship_model.dart';

// ── Bridge provider ────────────────────────────────────────────────────────
// Set this from DiscoverScreen.onAccept → main_shell switches to AI tab
// and AI screen auto-starts coaching.
final pendingCoachingScholarshipProvider =
    StateProvider<ScholarshipModel?>((ref) => null);

// ── Coaching task model ────────────────────────────────────────────────────

class CoachingTask {
  final String id;
  final String title;
  final String category; // 'document' | 'test' | 'online' | 'other'
  final String description;
  final bool isCompleted;

  const CoachingTask({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    this.isCompleted = false,
  });

  CoachingTask copyWith({bool? isCompleted}) => CoachingTask(
        id: id,
        title: title,
        category: category,
        description: description,
        isCompleted: isCompleted ?? this.isCompleted,
      );

  static List<CoachingTask> parseFromAiResponse(String response) {
    final regex = RegExp(r'<tasks>(.*?)</tasks>', dotAll: true);
    final match = regex.firstMatch(response);
    if (match == null) return [];
    try {
      final raw = jsonDecode(match.group(1)!.trim()) as List;
      return raw.map((e) => CoachingTask(
            id: e['id']?.toString() ?? UniqueKey().toString(),
            title: e['title'] as String? ?? '',
            category: e['category'] as String? ?? 'other',
            description: e['description'] as String? ?? '',
          )).toList();
    } catch (err) {
      debugPrint('[CoachingTask.parseFromAiResponse] parse error: $err');
      return [];
    }
  }

  /// Strip <tasks>…</tasks> block from the AI message before displaying.
  static String stripTasksBlock(String response) =>
      response.replaceAll(RegExp(r'<tasks>.*?</tasks>', dotAll: true), '').trim();
}

// ── Tasks notifier ─────────────────────────────────────────────────────────

class CoachingTasksNotifier extends StateNotifier<List<CoachingTask>> {
  CoachingTasksNotifier() : super([]);

  void setTasks(List<CoachingTask> tasks) => state = tasks;

  void toggle(String id) {
    state = state
        .map((t) => t.id == id ? t.copyWith(isCompleted: !t.isCompleted) : t)
        .toList();
  }

  void clear() => state = [];

  double get progress {
    if (state.isEmpty) return 0;
    return state.where((t) => t.isCompleted).length / state.length;
  }
}

final coachingTasksProvider =
    StateNotifierProvider<CoachingTasksNotifier, List<CoachingTask>>(
  (ref) => CoachingTasksNotifier(),
);

// ── Active coaching scholarship ────────────────────────────────────────────
// Persists even after the bridge is cleared.
final activeCoachingScholarshipProvider =
    StateProvider<ScholarshipModel?>((ref) => null);

// ── Coaching phase ─────────────────────────────────────────────────────────
enum CoachingPhase { idle, briefing, awaitingConfirmation, coaching }

final coachingPhaseProvider =
    StateProvider<CoachingPhase>((ref) => CoachingPhase.idle);
