class Kpi {
  final String id;
  final String userId;
  final String metric;
  final num target;
  final num achieved;
  final String period;

  Kpi({
    required this.id,
    required this.userId,
    required this.metric,
    required this.target,
    required this.achieved,
    required this.period,
  });

  double get pct =>
      target == 0 ? 0 : (achieved.toDouble() / target.toDouble() * 100);

  factory Kpi.fromMap(Map<String, dynamic> m) => Kpi(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        metric: (m['metric'] ?? '') as String,
        target: (m['target'] ?? 0) as num,
        achieved: (m['achieved'] ?? 0) as num,
        period: (m['period'] ?? '') as String,
      );
}
