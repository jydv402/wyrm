/// Domain model representing an individual task or checklist item.
class TaskItem {
  /// Unique identifier for the task.
  final String id;

  /// Display text describing the task.
  final String title;

  /// Whether the task has been marked as completed.
  final bool isCompleted;

  /// Priority tag: 'high' or 'normal'.
  final String priority;

  /// Timestamp when the task was created.
  final DateTime createdAt;

  const TaskItem({
    required this.id,
    required this.title,
    this.isCompleted = false,
    this.priority = 'normal',
    required this.createdAt,
  });

  /// Creates a copy of the task with specified properties overridden.
  TaskItem copyWith({
    String? id,
    String? title,
    bool? isCompleted,
    String? priority,
    DateTime? createdAt,
  }) {
    return TaskItem(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Serializes the task to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'is_completed': isCompleted,
      'priority': priority,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Deserializes a task from a JSON map with tolerant field name matching.
  factory TaskItem.fromJson(Map<String, dynamic> json) {
    final rawCompleted = json['is_completed'] ?? json['completed'];
    final rawDate = json['created_at'] ?? json['createdAt'];

    DateTime parsedDate;
    if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return TaskItem(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? json['text'] ?? '').toString(),
      isCompleted: rawCompleted is bool ? rawCompleted : false,
      priority: (json['priority'] ?? 'normal').toString(),
      createdAt: parsedDate,
    );
  }
}
