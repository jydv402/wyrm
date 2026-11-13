import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/data/app_database.dart';

import 'calendar_model.dart';

/// Immutable state containing calendar viewing context and temporal metrics.
class CalendarState {
  /// The currently selected day.
  final DateTime selectedDate;

  /// The first day of the month currently displayed in the grid.
  final DateTime viewMonth;

  /// All stored milestones.
  final List<CalendarMilestone> milestones;

  const CalendarState({
    required this.selectedDate,
    required this.viewMonth,
    this.milestones = const [],
  });

  /// Returns today's date normalized to midnight.
  static DateTime get todayMidnight {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Calculates day of year (1 - 365/366).
  int get dayOfYear {
    final startOfYear = DateTime(selectedDate.year, 1, 1);
    return selectedDate.difference(startOfYear).inDays + 1;
  }

  /// Whether the selected year is a leap year.
  bool get isLeapYear {
    final y = selectedDate.year;
    return (y % 4 == 0 && y % 100 != 0) || (y % 400 == 0);
  }

  /// Total days in the selected year.
  int get daysInYear => isLeapYear ? 366 : 365;

  /// Ratio of the current year elapsed (0.0 to 1.0).
  double get yearProgress {
    final now = DateTime.now();
    final startOfYear = DateTime(now.year, 1, 1);
    final endOfYear = DateTime(now.year + 1, 1, 1);
    final totalSeconds = endOfYear.difference(startOfYear).inSeconds;
    final elapsedSeconds = now.difference(startOfYear).inSeconds;
    return (elapsedSeconds / totalSeconds).clamp(0.0, 1.0);
  }

  /// Resolves current quarter index (1 - 4).
  int get currentQuarter => ((DateTime.now().month - 1) ~/ 3) + 1;

  /// Ratio of the current quarter elapsed (0.0 to 1.0).
  double get quarterProgress {
    final now = DateTime.now();
    final q = currentQuarter;
    final startMonth = (q - 1) * 3 + 1;
    final endMonth = q * 3 + 1;
    final startOfQuarter = DateTime(now.year, startMonth, 1);
    final endOfQuarter = endMonth > 12
        ? DateTime(now.year + 1, 1, 1)
        : DateTime(now.year, endMonth, 1);
    final totalSeconds = endOfQuarter.difference(startOfQuarter).inSeconds;
    final elapsedSeconds = now.difference(startOfQuarter).inSeconds;
    return (elapsedSeconds / totalSeconds).clamp(0.0, 1.0);
  }

  /// Resolves the primary pinned milestone, or the closest upcoming milestone.
  CalendarMilestone? get heroMilestone {
    final pinned = milestones.where((m) => m.isPinned).toList();
    if (pinned.isNotEmpty) return pinned.first;

    final upcoming = milestones.where((m) => m.daysRemaining() >= 0).toList()
      ..sort((a, b) => a.daysRemaining().compareTo(b.daysRemaining()));
    if (upcoming.isNotEmpty) return upcoming.first;

    if (milestones.isNotEmpty) return milestones.first;
    return null;
  }

  /// Calculates relative difference string between selected date and today.
  String get relativeDistanceText {
    final today = todayMidnight;
    final selected = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final diff = selected.difference(today).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return '+1 day from today';
    if (diff == -1) return '1 day ago';

    final absDiff = diff.abs();
    final weeks = absDiff ~/ 7;
    final remDays = absDiff % 7;

    String breakdown;
    if (weeks > 0 && remDays > 0) {
      breakdown = '$weeks w ${remDays}d';
    } else if (weeks > 0) {
      breakdown = '$weeks weeks';
    } else {
      breakdown = '$absDiff days';
    }

    if (diff > 0) {
      return '+$absDiff days from now ($breakdown)';
    } else {
      return '$absDiff days ago ($breakdown)';
    }
  }

  /// Checks if a date has any associated milestones.
  List<CalendarMilestone> milestonesForDate(DateTime date) {
    return milestones.where((m) {
      return m.targetDate.year == date.year &&
          m.targetDate.month == date.month &&
          m.targetDate.day == date.day;
    }).toList();
  }

  CalendarState copyWith({
    DateTime? selectedDate,
    DateTime? viewMonth,
    List<CalendarMilestone>? milestones,
  }) {
    return CalendarState(
      selectedDate: selectedDate ?? this.selectedDate,
      viewMonth: viewMonth ?? this.viewMonth,
      milestones: milestones ?? this.milestones,
    );
  }
}

/// Manages reactive calendar operations and local database persistence.
class CalendarNotifier extends Notifier<CalendarState> {
  @override
  CalendarState build() {
    final today = CalendarState.todayMidnight;
    _initializeFromDisk();
    return CalendarState(
      selectedDate: today,
      viewMonth: DateTime(today.year, today.month, 1),
    );
  }

  Future<void> _initializeFromDisk() async {
    final raw = await AppDatabase.readSection('calendar');
    final loaded = raw is List
        ? raw
            .whereType<Map<String, dynamic>>()
            .map(CalendarMilestone.fromJson)
            .toList()
        : <CalendarMilestone>[];
    state = state.copyWith(milestones: loaded);
  }

  /// Sets selected date and automatically syncs the viewed month if different.
  void selectDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final monthStart = DateTime(date.year, date.month, 1);
    state = state.copyWith(
      selectedDate: normalized,
      viewMonth: monthStart,
    );
  }

  /// Jumps back to current day.
  void resetToToday() {
    selectDate(CalendarState.todayMidnight);
  }

  /// Advances the viewed month by 1.
  void nextMonth() {
    final current = state.viewMonth;
    final next = DateTime(current.year, current.month + 1, 1);
    state = state.copyWith(viewMonth: next);
  }

  /// Moves the viewed month back by 1.
  void prevMonth() {
    final current = state.viewMonth;
    final prev = DateTime(current.year, current.month - 1, 1);
    state = state.copyWith(viewMonth: prev);
  }

  /// Sets viewed month and year directly.
  void setMonth(int year, int month) {
    state = state.copyWith(viewMonth: DateTime(year, month, 1));
  }

  /// Adds a new milestone and persists to local JSON database.
  Future<void> addMilestone(String title, DateTime targetDate, {bool isPinned = false}) async {
    final normalizedTarget = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final newMilestone = CalendarMilestone(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title.trim(),
      targetDate: normalizedTarget,
      isPinned: isPinned,
      createdAt: DateTime.now(),
    );

    final updated = [...state.milestones, newMilestone];
    state = state.copyWith(milestones: updated);
    await AppDatabase.writeSection(
      'calendar',
      updated.map((m) => m.toJson()).toList(),
    );
  }

  /// Deletes a milestone by ID and updates storage.
  Future<void> deleteMilestone(String id) async {
    final updated = state.milestones.where((m) => m.id != id).toList();
    state = state.copyWith(milestones: updated);
    await AppDatabase.writeSection(
      'calendar',
      updated.map((m) => m.toJson()).toList(),
    );
  }

  /// Toggles pinned state of a milestone.
  Future<void> togglePinMilestone(String id) async {
    final updated = state.milestones.map((m) {
      if (m.id == id) {
        return m.copyWith(isPinned: !m.isPinned);
      }
      return m;
    }).toList();
    state = state.copyWith(milestones: updated);
    await AppDatabase.writeSection(
      'calendar',
      updated.map((m) => m.toJson()).toList(),
    );
  }

  /// Reloads calendar milestones from disk.
  Future<void> reloadFromDisk() async {
    await _initializeFromDisk();
  }
}

/// Riverpod provider exposing calendar state and operations.
final calendarProvider = NotifierProvider<CalendarNotifier, CalendarState>(
  CalendarNotifier.new,
);
