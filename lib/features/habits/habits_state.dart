import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/data/repositories/habit_repository.dart';

import 'habit_model.dart';

/// Immutable state containing tracked habits and UI presentation state.
class HabitsState {
  /// All tracked habits.
  final List<HabitItem> habits;

  /// Active carousel index for the compact Small card mode.
  final int selectedCarouselIndex;

  const HabitsState({this.habits = const [], this.selectedCarouselIndex = 0});

  /// Resolves the currently focused habit in carousel mode, or null if list is empty.
  HabitItem? get activeHabit {
    if (habits.isEmpty) return null;
    final index = selectedCarouselIndex.clamp(0, habits.length - 1);
    return habits[index];
  }

  /// Total number of habits completed today.
  int completedTodayCount([DateTime? referenceDate]) {
    final today = referenceDate ?? DateTime.now();
    return habits.where((h) => h.isCompletedOn(today)).length;
  }

  HabitsState copyWith({List<HabitItem>? habits, int? selectedCarouselIndex}) {
    return HabitsState(
      habits: habits ?? this.habits,
      selectedCarouselIndex:
          selectedCarouselIndex ?? this.selectedCarouselIndex,
    );
  }
}

/// Manages reactive habits operations, check-ins, steppers, and persistence via [HabitRepository].
class HabitsNotifier extends Notifier<HabitsState> {
  HabitRepository get _repository => ref.read(habitRepositoryProvider);

  @override
  HabitsState build() {
    _initializeFromDisk();
    return const HabitsState();
  }

  Future<void> _initializeFromDisk() async {
    final loaded = await _repository.loadHabits();
    // Full completion history is kept in memory; month scoping happens at
    // render time (streak/heatmap math filters by date-key prefix), so
    // stripping here would permanently delete prior-month history on every
    // launch and any later save would write the loss back to disk.
    state = state.copyWith(habits: loaded, selectedCarouselIndex: 0);
  }

  /// Adds a new habit and persists to the database.
  Future<void> addHabit(HabitItem habit) async {
    final updated = [...state.habits, habit];
    state = state.copyWith(
      habits: updated,
      selectedCarouselIndex: updated.length - 1,
    );
    await _repository.saveHabits(updated);
  }

  /// Modifies an existing habit item and persists to the database.
  Future<void> editHabit(HabitItem habit) async {
    final updated = state.habits
        .map((h) => h.id == habit.id ? habit : h)
        .toList();
    state = state.copyWith(habits: updated);
    await _repository.saveHabits(updated);
  }

  /// Removes a habit item and adjusts carousel focus if needed.
  Future<void> deleteHabit(String id) async {
    final updated = state.habits.where((h) => h.id != id).toList();
    final newIndex = updated.isEmpty
        ? 0
        : math.min(state.selectedCarouselIndex, updated.length - 1);
    state = state.copyWith(habits: updated, selectedCarouselIndex: newIndex);
    await _repository.saveHabits(updated);
  }

  /// Toggles completion status for a habit on the given date (defaults to today).
  Future<void> toggleCompletion(String id, [DateTime? targetDate]) async {
    final date = targetDate ?? DateTime.now();
    final dateKey = HabitItem.dateKey(date);

    final updated = state.habits.map((habit) {
      if (habit.id != id) return habit;

      final currentCount = habit.completionCountOn(date);
      final newCompletions = Map<String, int>.from(habit.completions);

      if (currentCount >= habit.targetValue) {
        newCompletions.remove(dateKey);
      } else {
        newCompletions[dateKey] = habit.targetValue;
      }

      return habit.copyWith(completions: newCompletions);
    }).toList();

    state = state.copyWith(habits: updated);
    await _repository.saveHabits(updated);
  }

  /// Increments or decrements completion progress for a numeric habit on the given date.
  Future<void> stepCompletion(
    String id,
    int delta, [
    DateTime? targetDate,
  ]) async {
    final date = targetDate ?? DateTime.now();
    final dateKey = HabitItem.dateKey(date);

    final updated = state.habits.map((habit) {
      if (habit.id != id) return habit;

      final currentCount = habit.completionCountOn(date);
      final nextCount = math.max(0, currentCount + delta);
      final newCompletions = Map<String, int>.from(habit.completions);

      if (nextCount == 0) {
        newCompletions.remove(dateKey);
      } else {
        newCompletions[dateKey] = nextCount;
      }

      return habit.copyWith(completions: newCompletions);
    }).toList();

    state = state.copyWith(habits: updated);
    await _repository.saveHabits(updated);
  }

  /// Cycles carousel forward or backward in Small card mode.
  void cycleCarousel(int delta) {
    if (state.habits.isEmpty) return;
    final total = state.habits.length;
    var next = (state.selectedCarouselIndex + delta) % total;
    if (next < 0) next += total;
    state = state.copyWith(selectedCarouselIndex: next);
  }

  /// Sets carousel position directly.
  void setCarouselIndex(int index) {
    if (state.habits.isEmpty) return;
    final clamped = index.clamp(0, state.habits.length - 1);
    state = state.copyWith(selectedCarouselIndex: clamped);
  }

  /// Reloads habits from disk.
  Future<void> reloadFromDisk() async {
    await _initializeFromDisk();
  }
}

/// Global provider for habits state.
final habitsProvider = NotifierProvider<HabitsNotifier, HabitsState>(
  HabitsNotifier.new,
);
