import 'package:intl/intl.dart';

/// Bangla greeting per hour band (§0.9).
String banglaGreeting([DateTime? now]) {
  final h = (now ?? DateTime.now()).hour;
  if (h < 12) return 'Shuprobhat';
  if (h < 17) return 'Shubho oporahno';
  return 'Shubho shondha';
}

/// "6h 45m" style duration.
String fmtDuration(Duration d) {
  if (d.isNegative) d = Duration.zero;
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h == 0) return '${m}m';
  return '${h}h ${m}m';
}

String fmtClock(DateTime t) => DateFormat('HH:mm').format(t);
String fmtTime12(DateTime t) => DateFormat('h:mm a').format(t);
String fmtDayLong(DateTime d) => DateFormat('EEEE, d MMMM').format(d);
String fmtDayShort(DateTime d) => DateFormat('EEE, d MMM').format(d);
String fmtDeadline(DateTime d) => DateFormat('d MMM').format(d);

String currentPeriod([DateTime? now]) =>
    DateFormat('yyyy-MM').format(now ?? DateTime.now());

/// "2026-07" -> "Jul"
String periodLabel(String period) {
  try {
    return DateFormat('MMM').format(DateFormat('yyyy-MM').parse(period));
  } catch (_) {
    return period;
  }
}

/// Category slug -> display label.
const Map<String, String> categoryLabels = {
  'reporting': 'Reporting',
  'market_visit': 'Market Visit',
  'sales_call': 'Sales Call',
  'meeting': 'Meeting',
  'service_followup': 'Service Follow-up',
  'other': 'Other',
};

String categoryLabel(String slug) =>
    categoryLabels[slug] ?? (slug.isEmpty ? 'Other' : slug);
