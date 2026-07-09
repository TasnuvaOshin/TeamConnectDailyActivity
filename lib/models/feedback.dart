class FeedbackItem {
  final String id;
  final String fromUser;
  final String toUser;
  final int? rating; // 1..5, null for plain nudges/reminders
  final String comment;
  final DateTime createdAt;

  FeedbackItem({
    required this.id,
    required this.fromUser,
    required this.toUser,
    required this.comment,
    required this.createdAt,
    this.rating,
  });

  factory FeedbackItem.fromMap(Map<String, dynamic> m) => FeedbackItem(
        id: m['id'] as String,
        fromUser: m['from_user'] as String,
        toUser: m['to_user'] as String,
        rating: m['rating'] as int?,
        comment: (m['comment'] ?? '') as String,
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
      );
}
