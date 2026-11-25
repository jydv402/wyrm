/// Supported recurrence schedules for a [ReminderItem].
enum ReminderRecurrence {
  /// Fires once at a specific target date and time.
  once,

  /// Fires every day at the configured wall-clock hour and minute.
  daily,

  /// Fires Monday through Friday at the configured wall-clock hour and minute.
  weekdays,

  /// Fires on user-selected ISO weekdays (`1` = Monday .. `7` = Sunday).
  custom;

  /// Human-readable display label for UI chips and summaries.
  String get label {
    switch (this) {
      case ReminderRecurrence.once:
        return 'Once';
      case ReminderRecurrence.daily:
        return 'Daily';
      case ReminderRecurrence.weekdays:
        return 'Weekdays';
      case ReminderRecurrence.custom:
        return 'Custom';
    }
  }

  /// Canonical wire identifier used in JSON and WebSocket payloads.
  String get apiName => name;

  /// Parses a [ReminderRecurrence] from dynamic JSON/API values safely.
  static ReminderRecurrence fromString(dynamic value) {
    if (value is ReminderRecurrence) return value;
    if (value == null) return ReminderRecurrence.once;
    final normalized = value
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
    switch (normalized) {
      case 'once':
      case 'one_time':
      case 'onetime':
      case 'single':
        return ReminderRecurrence.once;
      case 'daily':
      case 'everyday':
      case 'every_day':
        return ReminderRecurrence.daily;
      case 'weekdays':
      case 'weekday':
      case 'workdays':
      case 'mon_fri':
        return ReminderRecurrence.weekdays;
      case 'custom':
      case 'weekly':
        return ReminderRecurrence.custom;
      default:
        return ReminderRecurrence.once;
    }
  }
}

/// Immutable domain model representing a scheduled or recurring reminder alarm.
class ReminderItem {
  /// Unique identifier for the reminder.
  final String id;

  /// Title describing what the reminder is for.
  final String title;

  /// Target date/time (carries target instant for [ReminderRecurrence.once]
  /// and wall-clock hour/minute for repeating schedules).
  final DateTime scheduledAt;

  /// Recurrence pattern governing when the reminder fires.
  final ReminderRecurrence recurrence;

  /// Sorted, unique ISO 8601 weekdays (`1` = Monday .. `7` = Sunday) used when
  /// [recurrence] is [ReminderRecurrence.custom].
  final List<int> customWeekdays;

  /// Whether the reminder is active and eligible to fire.
  final bool isEnabled;

  /// Active snooze target timestamp if the user snoozed this reminder.
  final DateTime? snoozedUntil;

  /// Timestamp of the last occurrence that fired or was dismissed.
  final DateTime? lastTriggeredAt;

  /// Timestamp when the reminder was created.
  final DateTime createdAt;

  /// Creates an immutable [ReminderItem].
  const ReminderItem({
    required this.id,
    required this.title,
    required this.scheduledAt,
    this.recurrence = ReminderRecurrence.once,
    this.customWeekdays = const <int>[],
    this.isEnabled = true,
    this.snoozedUntil,
    this.lastTriggeredAt,
    required this.createdAt,
  });

  /// Normalizes raw weekday indices into a sorted, unique list within `1..7`.
  static List<int> normalizeWeekdays(Iterable<int> weekdays) {
    final valid = <int>{};
    for (final day in weekdays) {
      if (day >= DateTime.monday && day <= DateTime.sunday) {
        valid.add(day);
      }
    }
    final sorted = valid.toList()..sort();
    return List<int>.unmodifiable(sorted);
  }

  /// Whether this reminder's recurrence rule permits firing on [isoWeekday]
  /// (`1` = Monday .. `7` = Sunday).
  bool matchesWeekday(int isoWeekday) {
    switch (recurrence) {
      case ReminderRecurrence.once:
      case ReminderRecurrence.daily:
        return true;
      case ReminderRecurrence.weekdays:
        return isoWeekday >= DateTime.monday && isoWeekday <= DateTime.friday;
      case ReminderRecurrence.custom:
        return customWeekdays.contains(isoWeekday);
    }
  }

  /// Returns a copy with specified fields replaced or nullable timestamps cleared.
  ReminderItem copyWith({
    String? id,
    String? title,
    DateTime? scheduledAt,
    ReminderRecurrence? recurrence,
    List<int>? customWeekdays,
    bool? isEnabled,
    DateTime? snoozedUntil,
    bool clearSnoozedUntil = false,
    DateTime? lastTriggeredAt,
    bool clearLastTriggeredAt = false,
    DateTime? createdAt,
  }) {
    return ReminderItem(
      id: id ?? this.id,
      title: title ?? this.title,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      recurrence: recurrence ?? this.recurrence,
      customWeekdays: customWeekdays != null
          ? normalizeWeekdays(customWeekdays)
          : this.customWeekdays,
      isEnabled: isEnabled ?? this.isEnabled,
      snoozedUntil: clearSnoozedUntil
          ? null
          : (snoozedUntil ?? this.snoozedUntil),
      lastTriggeredAt: clearLastTriggeredAt
          ? null
          : (lastTriggeredAt ?? this.lastTriggeredAt),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Serializes this reminder to snake_case JSON matching database & API shape.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'scheduled_at': scheduledAt.toIso8601String(),
      'recurrence': recurrence.apiName,
      'custom_weekdays': normalizeWeekdays(customWeekdays),
      'is_enabled': isEnabled,
      'snoozed_until': snoozedUntil?.toIso8601String(),
      'last_triggered_at': lastTriggeredAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Deserializes a [ReminderItem] tolerating both snake_case and camelCase keys.
  factory ReminderItem.fromJson(Map<String, dynamic> json) {
    final epochZero = DateTime.fromMillisecondsSinceEpoch(0);
    final rawScheduled =
        json['scheduled_at'] ?? json['scheduledAt'] ?? json['target_at'];
    final rawCreated = json['created_at'] ?? json['createdAt'];
    final rawSnoozed = json['snoozed_until'] ?? json['snoozedUntil'];
    final rawLastTriggered =
        json['last_triggered_at'] ?? json['lastTriggeredAt'];
    final rawEnabled =
        json['is_enabled'] ?? json['isEnabled'] ?? json['enabled'];
    final rawWeekdays =
        json['custom_weekdays'] ?? json['customWeekdays'] ?? json['weekdays'];

    return ReminderItem(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? json['text'] ?? json['name'] ?? '').toString(),
      scheduledAt: _parseDateTime(rawScheduled) ?? epochZero,
      recurrence: ReminderRecurrence.fromString(json['recurrence']),
      customWeekdays: _parseWeekdays(rawWeekdays),
      isEnabled: _parseBool(rawEnabled, defaultValue: true),
      snoozedUntil: _parseDateTime(rawSnoozed),
      lastTriggeredAt: _parseDateTime(rawLastTriggered),
      createdAt: _parseDateTime(rawCreated) ?? epochZero,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReminderItem &&
        other.id == id &&
        other.title == title &&
        other.scheduledAt == scheduledAt &&
        other.recurrence == recurrence &&
        _intListEquals(
          normalizeWeekdays(other.customWeekdays),
          normalizeWeekdays(customWeekdays),
        ) &&
        other.isEnabled == isEnabled &&
        other.snoozedUntil == snoozedUntil &&
        other.lastTriggeredAt == lastTriggeredAt &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    scheduledAt,
    recurrence,
    Object.hashAll(normalizeWeekdays(customWeekdays)),
    isEnabled,
    snoozedUntil,
    lastTriggeredAt,
    createdAt,
  );

  static DateTime? _parseDateTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is num) {
      return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      return DateTime.tryParse(trimmed);
    }
    return null;
  }

  static List<int> _parseWeekdays(dynamic raw) {
    if (raw is! Iterable) return const <int>[];
    final parsed = <int>[];
    for (final entry in raw) {
      if (entry is num) {
        parsed.add(entry.toInt());
      } else if (entry != null) {
        final value = int.tryParse(entry.toString().trim());
        if (value != null) parsed.add(value);
      }
    }
    return normalizeWeekdays(parsed);
  }

  static bool _parseBool(dynamic raw, {required bool defaultValue}) {
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      final normalized = raw.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return defaultValue;
  }

  static bool _intListEquals(List<int> a, List<int> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
