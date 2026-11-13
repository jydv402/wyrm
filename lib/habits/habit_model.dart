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
    if (normalized == 'numeric' || normalized == 'counter' || normalized == 'target') {
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

  /// Accent color hex representation.
  final String colorHex;

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
    this.colorHex = '#A0D2B4',
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
    final yesterdayInMonth = yesterdayMidnight.month == ref.month && yesterdayMidnight.year == ref.year;
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

    while (cursor.month == ref.month && cursor.year == ref.year && isCompletedOn(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return streak;
  }

  /// Calculates the best unbroken completion streak achieved within the reference month.
  int bestStreak([DateTime? referenceDate]) {
    final ref = referenceDate ??
        (completions.isNotEmpty
            ? (DateTime.tryParse(completions.keys.first) ?? createdAt)
            : createdAt);
    final prefix = '${ref.year.toString().padLeft(4, '0')}-${ref.month.toString().padLeft(2, '0')}-';
    final completedDateKeys = completions.entries
        .where((entry) => entry.value >= targetValue && entry.key.startsWith(prefix))
        .map((entry) => entry.key)
        .toList();

    if (completedDateKeys.isEmpty) return 0;

    final dates = <DateTime>[];
    for (final key in completedDateKeys) {
      final parts = key.split('-');
      if (parts.length == 3) {
        final year = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final day = int.tryParse(parts[2]);
        if (year != null && month != null && day != null) {
          dates.add(DateTime(year, month, day));
        }
      }
    }

    if (dates.isEmpty) return 0;

    dates.sort((a, b) => a.compareTo(b));

    var maxStreak = 1;
    var current = 1;

    for (var i = 1; i < dates.length; i++) {
      final prev = dates[i - 1];
      final curr = dates[i];
      final diff = curr.difference(prev).inDays;

      if (diff == 1) {
        current++;
        if (current > maxStreak) {
          maxStreak = current;
        }
      } else if (diff > 1) {
        current = 1;
      }
    }

    return maxStreak;
  }

  /// Counts the total number of days completed in the designated month.
  int monthCompletedDaysCount([DateTime? referenceDate]) {
    final ref = referenceDate ?? DateTime.now();
    final prefix = '${ref.year.toString().padLeft(4, '0')}-${ref.month.toString().padLeft(2, '0')}-';
    return completions.entries
        .where((entry) => entry.key.startsWith(prefix) && entry.value >= targetValue)
        .length;
  }

  /// Generates a GitHub-style columns matrix (7 weekday rows per column) for the given month.
  List<List<HeatmapCellData>> getMonthlyHeatmapColumns(
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

    final columns = <List<HeatmapCellData>>[];
    var currentColumn = <HeatmapCellData>[];

    for (var i = 0; i < firstDayWeekdayOffset; i++) {
      currentColumn.add(const HeatmapCellData(
        dayNumber: 0,
        isCurrentMonth: false,
        isFuture: false,
        isToday: false,
        isCompleted: false,
        intensity: 0.0,
        count: 0,
      ));
    }

    for (var day = 1; day <= totalDays; day++) {
      final date = DateTime(year, month, day);
      final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
      final isFuture = date.isAfter(DateTime(today.year, today.month, today.day));
      final count = completionCountOn(date);
      final isCompleted = count >= targetValue;

      double intensity = 0.0;
      if (isCompleted) {
        intensity = 1.0;
      } else if (count > 0 && targetValue > 0) {
        intensity = (count / targetValue).clamp(0.2, 0.8);
      }

      currentColumn.add(HeatmapCellData(
        date: date,
        dayNumber: day,
        isCurrentMonth: true,
        isFuture: isFuture,
        isToday: isToday,
        isCompleted: isCompleted,
        intensity: intensity,
        count: count,
      ));

      if (currentColumn.length == 7) {
        columns.add(currentColumn);
        currentColumn = <HeatmapCellData>[];
      }
    }

    if (currentColumn.isNotEmpty) {
      while (currentColumn.length < 7) {
        currentColumn.add(const HeatmapCellData(
          dayNumber: 0,
          isCurrentMonth: false,
          isFuture: false,
          isToday: false,
          isCompleted: false,
          intensity: 0.0,
          count: 0,
        ));
      }
      columns.add(currentColumn);
    }

    return columns;
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

    final prevMonthLastDay = DateTime(year, month, 0).day;
    for (var i = firstDayWeekdayOffset - 1; i >= 0; i--) {
      final prevDate = DateTime(year, month - 1, prevMonthLastDay - i);
      currentWeek.add(HeatmapCellData(
        date: prevDate,
        dayNumber: prevDate.day,
        isCurrentMonth: false,
        isFuture: false,
        isToday: false,
        isCompleted: false,
        intensity: 0.0,
        count: 0,
      ));
    }

    for (var day = 1; day <= totalDays; day++) {
      final date = DateTime(year, month, day);
      final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
      final isFuture = date.isAfter(DateTime(today.year, today.month, today.day));
      final count = completionCountOn(date);
      final isCompleted = count >= targetValue;

      double intensity = 0.0;
      if (isCompleted) {
        intensity = 1.0;
      } else if (count > 0 && targetValue > 0) {
        intensity = (count / targetValue).clamp(0.2, 0.8);
      }

      currentWeek.add(HeatmapCellData(
        date: date,
        dayNumber: day,
        isCurrentMonth: true,
        isFuture: isFuture,
        isToday: isToday,
        isCompleted: isCompleted,
        intensity: intensity,
        count: count,
      ));

      if (currentWeek.length == 7) {
        weeks.add(currentWeek);
        currentWeek = <HeatmapCellData>[];
      }
    }

    if (currentWeek.isNotEmpty) {
      var nextDay = 1;
      while (currentWeek.length < 7) {
        final nextDate = DateTime(year, month + 1, nextDay++);
        currentWeek.add(HeatmapCellData(
          date: nextDate,
          dayNumber: nextDate.day,
          isCurrentMonth: false,
          isFuture: false,
          isToday: false,
          isCompleted: false,
          intensity: 0.0,
          count: 0,
        ));
      }
      weeks.add(currentWeek);
    }

    return weeks;
  }

  /// Counts the total number of days completed in the 7-day period starting from weekStart.
  int weekProgress(DateTime weekStart) {
    var count = 0;
    for (var i = 0; i < 7; i++) {
      final day = weekStart.add(Duration(days: i));
      if (isCompletedOn(day)) {
        count++;
      }
    }
    return count;
  }

  /// Creates a copy with designated modifications.
  HabitItem copyWith({
    String? id,
    String? title,
    HabitType? type,
    int? targetValue,
    String? unit,
    String? iconName,
    String? colorHex,
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
      colorHex: colorHex ?? this.colorHex,
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
      'color_hex': colorHex,
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
        final countVal = value is num ? value.toInt() : int.tryParse(value.toString()) ?? 0;
        parsedCompletions[keyStr] = countVal;
      });
    }

    final rawCreatedAt = json['created_at'] ?? json['createdAt'];
    final parsedCreatedAt = rawCreatedAt is String
        ? DateTime.tryParse(rawCreatedAt) ?? DateTime.now()
        : DateTime.now();

    final rawTarget = json['target_value'] ?? json['targetValue'] ?? json['target'];
    final parsedTarget = rawTarget is num
        ? rawTarget.toInt()
        : int.tryParse(rawTarget?.toString() ?? '1') ?? 1;

    return HabitItem(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: (json['title'] ?? json['name'] ?? 'Habit').toString(),
      type: HabitType.fromString(json['type']?.toString()),
      targetValue: parsedTarget < 1 ? 1 : parsedTarget,
      unit: json['unit']?.toString(),
      iconName: (json['icon_name'] ?? json['iconName'] ?? json['icon'] ?? 'bolt').toString(),
      colorHex: (json['color_hex'] ?? json['colorHex'] ?? json['color'] ?? '#A0D2B4').toString(),
      completions: parsedCompletions,
      createdAt: parsedCreatedAt,
    );
  }
}

/// Represents a single cell in the GitHub-style monthly habit heatmap.
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

