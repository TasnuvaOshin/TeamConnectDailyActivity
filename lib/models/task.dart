class TaskItem {
  final String id;
  final String title;
  final String? description;
  final String status;     // open / in_progress / done / blocked
  final String priority;   // low / medium / high / urgent
  final String assignerId;
  final String assigneeId;
  final DateTime? dueDate;
  final DateTime createdAt;

  TaskItem({
    required this.id,
    required this.title,
    required this.status,
    required this.priority,
    required this.assignerId,
    required this.assigneeId,
    required this.createdAt,
    this.description,
    this.dueDate,
  });

  factory TaskItem.fromMap(Map<String, dynamic> m) => TaskItem(
        id: m['id'] as String,
        title: (m['title'] ?? '') as String,
        description: m['description'] as String?,
        status: (m['status'] ?? 'open') as String,
        priority: (m['priority'] ?? 'medium') as String,
        assignerId: m['assigner_id'] as String,
        assigneeId: m['assignee_id'] as String,
        dueDate: m['due_date'] != null
            ? DateTime.parse(m['due_date'] as String).toLocal()
            : null,
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
      );

  bool get isOpen => status != 'done';
}
