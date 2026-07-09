class Training {
  final String id;
  final String userId;
  final String title;
  final String status; // completed / planned
  final DateTime? completedDate;

  Training({
    required this.id,
    required this.userId,
    required this.title,
    required this.status,
    this.completedDate,
  });

  bool get isCompleted => status == 'completed';

  factory Training.fromMap(Map<String, dynamic> m) => Training(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        title: (m['title'] ?? '') as String,
        status: (m['status'] ?? 'completed') as String,
        completedDate: m['completed_date'] != null
            ? DateTime.parse(m['completed_date'] as String)
            : null,
      );
}
