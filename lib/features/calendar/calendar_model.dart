/// Model representing a temporal milestone or countdown event on the calendar.
class CalendarMilestone {
  /// Unique identifier for the milestone.
  final String id;

  /// Human-readable title or description of the milestone.
  final String title;

  /// Target date and time associated with the milestone.
  final DateTime targetDate;

  /// Whether this milestone is pinned to the prominent countdown pill.
  final bool isPinned;

  /// Creation timestamp.
  final DateTime createdAt;

  const CalendarMilestone({
    required this.id,
    required this.title,
    required this.targetDate,
    this.isPinned = false,
    required this.createdAt,
  });

  /// Calculates days difference between target date and the reference date (defaults to today).
  int daysRemaining([DateTime? referenceDate]) {
    final ref = referenceDate ?? DateTime.now();
    final todayMidnight = DateTime(ref.year, ref.month, ref.day);
    final targetMidnight = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
    );
    return targetMidnight.difference(todayMidnight).inDays;
  }

  /// Whether the milestone date is today.
  bool get isToday => daysRemaining() == 0;

  /// Whether the milestone date has elapsed.
  bool get isPast => daysRemaining() < 0;

  /// Formatted relative text representation.
  String get relativeLabel {
    final days = daysRemaining();
    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    if (days == -1) return 'Yesterday';
    if (days > 0) {
      if (days >= 14 && days % 7 == 0) {
        final weeks = days ~/ 7;
        return 'In $weeks weeks';
      }
      return 'In $days days';
    }
    final absDays = days.abs();
    if (absDays >= 14 && absDays % 7 == 0) {
      final weeks = absDays ~/ 7;
      return '$weeks weeks ago';
    }
    return '$absDays days ago';
  }

  /// Returns a copy of this milestone with updated attributes.
  CalendarMilestone copyWith({
    String? id,
    String? title,
    DateTime? targetDate,
    bool? isPinned,
    DateTime? createdAt,
  }) {
    return CalendarMilestone(
      id: id ?? this.id,
      title: title ?? this.title,
      targetDate: targetDate ?? this.targetDate,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Serializes milestone to JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'target_date': targetDate.toIso8601String(),
      'is_pinned': isPinned,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Deserializes milestone from JSON with tolerant parsing.
  factory CalendarMilestone.fromJson(Map<String, dynamic> json) {
    final rawDate = json['target_date'] ?? json['date'] ?? json['targetDate'];
    final parsedTargetDate = rawDate is String
        ? DateTime.tryParse(rawDate) ?? DateTime.now()
        : DateTime.now();

    final rawCreatedAt = json['created_at'] ?? json['createdAt'];
    final parsedCreatedAt = rawCreatedAt is String
        ? DateTime.tryParse(rawCreatedAt) ?? DateTime.now()
        : DateTime.now();

    final rawPinned = json['is_pinned'] ?? json['pinned'] ?? json['isPinned'];
    final isPinned = rawPinned is bool
        ? rawPinned
        : (rawPinned == 1 || rawPinned == 'true');

    return CalendarMilestone(
      id:
          json['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: (json['title'] ?? json['text'] ?? json['name'] ?? 'Milestone')
          .toString(),
      targetDate: parsedTargetDate,
      isPinned: isPinned,
      createdAt: parsedCreatedAt,
    );
  }
}
