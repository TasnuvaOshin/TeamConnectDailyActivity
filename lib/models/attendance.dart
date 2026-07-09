class Attendance {
  final String id;
  final String userId;
  final DateTime date;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final double? lat;
  final double? lng;
  final String? note;

  Attendance({
    required this.id,
    required this.userId,
    required this.date,
    this.checkIn,
    this.checkOut,
    this.lat,
    this.lng,
    this.note,
  });

  factory Attendance.fromMap(Map<String, dynamic> m) => Attendance(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        date: DateTime.parse(m['date'] as String),
        checkIn: m['check_in'] != null
            ? DateTime.parse(m['check_in'] as String).toLocal()
            : null,
        checkOut: m['check_out'] != null
            ? DateTime.parse(m['check_out'] as String).toLocal()
            : null,
        lat: (m['lat'] as num?)?.toDouble(),
        lng: (m['lng'] as num?)?.toDouble(),
        note: m['note'] as String?,
      );

  Duration get worked {
    if (checkIn == null) return Duration.zero;
    final end = checkOut ?? DateTime.now();
    return end.difference(checkIn!);
  }
}
