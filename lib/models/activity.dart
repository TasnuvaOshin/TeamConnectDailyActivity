class Activity {
  final String id;
  final String userId;
  final String type; // reporting / market_visit / sales_call / meeting / service_followup / other
  final String title;
  final String? notes;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? location;
  final int breakMinutes;
  final double? lat;
  final double? lng;

  Activity({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.startedAt,
    this.notes,
    this.endedAt,
    this.location,
    this.breakMinutes = 0,
    this.lat,
    this.lng,
  });

  bool get isBreak => breakMinutes > 0;

  Duration get duration =>
      endedAt == null ? Duration.zero : endedAt!.difference(startedAt);

  factory Activity.fromMap(Map<String, dynamic> m) => Activity(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        type: (m['type'] ?? 'other') as String,
        title: (m['title'] ?? '') as String,
        notes: m['notes'] as String?,
        startedAt: DateTime.parse(m['started_at'] as String).toLocal(),
        endedAt: m['ended_at'] != null
            ? DateTime.parse(m['ended_at'] as String).toLocal()
            : null,
        location: m['location'] as String?,
        breakMinutes: (m['break_minutes'] ?? 0) as int,
        lat: (m['lat'] as num?)?.toDouble(),
        lng: (m['lng'] as num?)?.toDouble(),
      );
}
