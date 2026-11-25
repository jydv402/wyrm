/// Supported goal structures for tracked habits.
enum HabitType {
  /// Simple binary check-in (Done or Not Done).
  binary,

  /// Quantitative goal with measurable target and unit steppers.
  numeric;

  /// Resolves the human-readable label.
  String get label {
    switch (this) {
      case HabitType.binary:
        return 'Check-in';
      case HabitType.numeric:
        return 'Target Count';
    }
  }

  /// Parses a HabitType from dynamic input string safely.
  static HabitType fromString(String? value) {
    if (value == null) return HabitType.binary;
    final normalized = value.toLowerCase().trim();
    if (normalized == 'numeric' ||
        normalized == 'counter' ||
        normalized == 'target') {
      return HabitType.numeric;
    }
    return HabitType.binary;
  }
}

/// Immutable data model representing a tracked daily habit item.
class HabitItem {
  /// Unique identifier for the habit.
  final String id;

  /// Display title of the habit.
  final String title;

  /// Goal type (binary check-in or numeric target).
  final HabitType type;

  /// Target count value (e.g. 1 for binary, 8 for numeric cups).
  final int targetValue;

  /// Optional measurement unit label (e.g. "cups", "mins", "pages").
  final String? unit;

  /// Icon identifier glyph name.
  final String iconName;

  /// Completion records keyed by ISO date string (YYYY-MM-DD) mapping to count achieved.
  final Map<String, int> completions;

  /// Creation timestamp.
  final DateTime createdAt;

  const HabitItem({
    required this.id,
    required this.title,
    this.type = HabitType.binary,
    this.targetValue = 1,
    this.unit,
    this.iconName = 'bolt',
    this.completions = const {},
    required this.createdAt,
  });

  /// Normalizes any DateTime instance to a standard ISO YYYY-MM-DD key.
  static String dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Retrieves the recorded progress count for the specified date.
  int completionCountOn(DateTime date) {
    return completions[dateKey(date)] ?? 0;
  }

  /// Evaluates whether the habit meets or exceeds its completion target on the given date.
  bool isCompletedOn(DateTime date) {
    return completionCountOn(date) >= targetValue;
  }

  /// Calculates consecutive completion streak within the reference month (defaults to current month).
  /// Implements same-day grace: an uncompleted today does not break an active streak from yesterday.
  /// Resets to 0 at the start of each month to align with the monthly heatmap.
  int currentStreak([DateTime? referenceDate]) {
    final ref = referenceDate ?? DateTime.now();
    final todayMidnight = DateTime(ref.year, ref.month, ref.day);

    final todayDone = isCompletedOn(todayMidnight);
    final yesterdayMidnight = todayMidnight.subtract(const Duration(days: 1));
    final yesterdayInMonth =
        yesterdayMidnight.month == ref.month &&
        yesterdayMidnight.year == ref.year;
    final yesterdayDone = yesterdayInMonth && isCompletedOn(yesterdayMidnight);

    if (!todayDone && !yesterdayDone) {
      return 0;
    }

    var streak = todayDone ? 1 : 0;
    var cursor = yesterdayMidnight;

    if (!todayDone && yesterdayDone) {
      streak = 1;
      cursor = cursor.subtract(const Duration(days: 1));
    } else if (todayDone) {
      cursor = yesterdayMidnight;
    }

    while (cursor.month == ref.month &&
        cursor.year == ref.year &&
        isCompletedOn(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return streak;
  }

  /// Counts the total number of days completed in the designated month.
  int monthCompletedDaysCount([DateTime? referenceDate]) {
    final ref = referenceDate ?? DateTime.now();
    final prefix =
        '${ref.year.toString().padLeft(4, '0')}-${ref.month.toString().padLeft(2, '0')}-';
    return completions.entries
        .where(
          (entry) => entry.key.startsWith(prefix) && entry.value >= targetValue,
        )
        .length;
  }

  /// Generates a calendar matrix (5 or 6 rows, each having 7 weekday columns) for the given month.
  List<List<HeatmapCellData>> getMonthlyCalendarWeeks(
    DateTime monthRef, {
    required bool startWeekOnMonday,
    DateTime? todayDate,
  }) {
    final today = todayDate ?? DateTime.now();
    final year = monthRef.year;
    final month = monthRef.month;
    final totalDays = DateTime(year, month + 1, 0).day;
    final firstDayDate = DateTime(year, month, 1);

    final firstDayWeekdayOffset = startWeekOnMonday
        ? (firstDayDate.weekday - 1) % 7
        : firstDayDate.weekday % 7;

    final weeks = <List<HeatmapCellData>>[];
    var currentWeek = <HeatmapCellData>[];

    for (var i = 0; i < firstDayWeekdayOffset; i++) {
      currentWeek.add(
        const HeatmapCellData(
          date: null,
          dayNumber: 0,
          isCurrentMonth: false,
          isFuture: false,
          isToday: false,
          isCompleted: false,
          intensity: 0.0,
          count: 0,
        ),
      );
    }

    for (var day = 1; day <= totalDays; day++) {
      final date = DateTime(year, month, day);
      final isToday =
          date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
      final isFuture = date.isAfter(
        DateTime(today.year, today.month, today.day),
      );
      final count = completionCountOn(date);
      final isCompleted = count >= targetValue;

      double intensity = 0.0;
      if (isCompleted) {
        intensity = 1.0;
      } else if (count > 0 && targetValue > 0) {
        intensity = (count / targetValue).clamp(0.2, 0.8);
      }

      currentWeek.add(
        HeatmapCellData(
          date: date,
          dayNumber: day,
          isCurrentMonth: true,
          isFuture: isFuture,
          isToday: isToday,
          isCompleted: isCompleted,
          intensity: intensity,
          count: count,
        ),
      );

      if (currentWeek.length == 7) {
        weeks.add(currentWeek);
        currentWeek = <HeatmapCellData>[];
      }
    }

    if (currentWeek.isNotEmpty) {
      while (currentWeek.length < 7) {
        currentWeek.add(
          const HeatmapCellData(
            date: null,
            dayNumber: 0,
            isCurrentMonth: false,
            isFuture: false,
            isToday: false,
            isCompleted: false,
            intensity: 0.0,
            count: 0,
          ),
        );
      }
      weeks.add(currentWeek);
    }

    return weeks;
  }

  /// Creates a copy with designated modifications.
  HabitItem copyWith({
    String? id,
    String? title,
    HabitType? type,
    int? targetValue,
    String? unit,
    String? iconName,
    Map<String, int>? completions,
    DateTime? createdAt,
  }) {
    return HabitItem(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      targetValue: targetValue ?? this.targetValue,
      unit: unit ?? this.unit,
      iconName: iconName ?? this.iconName,
      completions: completions ?? this.completions,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Serializes the habit item to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'type': type.name,
      'target_value': targetValue,
      'targetValue': targetValue,
      'unit': unit,
      'icon_name': iconName,
      'iconName': iconName,
      'completions': completions,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Deserializes a habit item from a JSON map with tolerant type casting.
  factory HabitItem.fromJson(Map<String, dynamic> json) {
    final rawCompletions = json['completions'];
    final parsedCompletions = <String, int>{};
    if (rawCompletions is Map) {
      rawCompletions.forEach((key, value) {
        final keyStr = key.toString();
        final countVal = value is num
            ? value.toInt()
            : int.tryParse(value.toString()) ?? 0;
        parsedCompletions[keyStr] = countVal;
      });
    }

    final rawCreatedAt = json['created_at'] ?? json['createdAt'];
    final parsedCreatedAt = rawCreatedAt is String
        ? DateTime.tryParse(rawCreatedAt) ?? DateTime.now()
        : DateTime.now();

    final rawTarget =
        json['target_value'] ?? json['targetValue'] ?? json['target'];
    final parsedTarget = rawTarget is num
        ? rawTarget.toInt()
        : int.tryParse(rawTarget?.toString() ?? '1') ?? 1;

    return HabitItem(
      id:
          json['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: (json['title'] ?? json['name'] ?? 'Habit').toString(),
      type: HabitType.fromString(json['type']?.toString()),
      targetValue: parsedTarget < 1 ? 1 : parsedTarget,
      unit: json['unit']?.toString(),
      iconName:
          (json['icon_name'] ?? json['iconName'] ?? json['icon'] ?? 'bolt')
              .toString(),
      completions: parsedCompletions,
      createdAt: parsedCreatedAt,
    );
  }
}

/// Represents a single cell in the monthly habit calendar heatmap.
class HeatmapCellData {
  /// The specific calendar date represented, or null if this is an empty padding cell.
  final DateTime? date;

  /// Day of month (1..31), or 0 for padding cells.
  final int dayNumber;

  /// True if the cell belongs to the active month.
  final bool isCurrentMonth;

  /// True if the date is in the future.
  final bool isFuture;

  /// True if the date matches today.
  final bool isToday;

  /// True if the habit goal was completed on this date.
  final bool isCompleted;

  /// Progress fraction from 0.0 to 1.0 (for partial intensity shading).
  final double intensity;

  /// Recorded completion count achieved on this date.
  final int count;

  const HeatmapCellData({
    this.date,
    required this.dayNumber,
    required this.isCurrentMonth,
    required this.isFuture,
    required this.isToday,
    required this.isCompleted,
    required this.intensity,
    required this.count,
  });
}
