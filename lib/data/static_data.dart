import 'dart:convert';
import '../hierarchy.dart';
import '../models/activity.dart';
import '../models/attendance.dart';
import '../models/feedback.dart';
import '../models/kpi.dart';
import '../models/profile.dart';
import 'emp_data_raw.dart';
import '../models/task.dart';
import '../models/training.dart';
import '../util/fmt.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// STATIC FRONTEND-ONLY DATA
///
/// The third-party API has no org hierarchy, KPIs, attendance, feedback,
/// trainings or cross-user task data. Everything in this file is a
/// deterministic in-app demo dataset that powers those screens.
/// See IMPLEMENTATION_STATUS.md for the full API-vs-static breakdown.
/// ─────────────────────────────────────────────────────────────────────────

/// Deterministic pseudo-random in [0,1) from a string seed.
double _rand(String seed) {
  var h = 0;
  for (final c in seed.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return (h % 1000) / 1000.0;
}

/// The 17-person demo org (one employee per level, linear manager chain).
final List<Profile> staticOrg = List.unmodifiable([
  for (var l = 1; l <= 17; l++)
    Profile(
      id: 'static-${l.toString().padLeft(3, '0')}',
      fullName: _names[l - 1],
      employeeId: _employeeIds[l - 1],
      email: 'aci-${_employeeIds[l - 1]}@teamconnect.demo',
      roleLevel: l,
      designation: _realDesignations[l - 1],
      department: _departments[l - 1],
      zone: _zones[l % _zones.length],
      managerId: l == 1 ? null : 'static-${(l - 1).toString().padLeft(3, '0')}',
      phone: '017111111${(10 + l)}',
    ),
]);

const _names = [
  'Subrata Ranjan Das',
  'Hyoe Sakai',
  'Md Azam Ali',
  'MD.Asif Uddin',
  'Md Khairul Ahsan',
  'Asif Faisal Rumy',
  'John Doe',
  'Yeasir Ibne Ashab',
  'Md. Arafat Hossain',
  'Md. Nurul Muntazir',
  'Tanvir Ahmed Tanim',
  'Mohammad Asifur Rahman',
  'Md. Kamrul Ahsan',
  'Mohammad Bayzid',
  'Md. Mahbubur Rahman',
  'Saif Mushfiq',
  'Md. Abu Bakkar Siddik',
];

const _employeeIds = [
  '1021',
  '58149',
  '1291',
  '3221',
  '12986',
  '6792',
  '12345',
  '8338',
  '11380',
  '16271',
  'U066',
  '37814',
  '34793',
  '38963',
  '31223',
  '33017',
  '46090',
];

const _realDesignations = [
  'Managing Director, Motors',
  'Deputy Managing Director, Motors',
  'Director, Sales Network Quality Development',
  'CBO',
  'Deputy Director, Credit Management',
  'DBD, Motors',
  'Business Manager',
  'Sr. GM',
  'GM',
  'Marketing Manager',
  'Assistant Marketing Manager',
  'Asst. Product Manager',
  'Product Manager',
  'Deputy Product Manager',
  'Assistant Product Manager',
  'Senior Product Executive',
  'Product Executive',
];

const _departments = [
  'Motors Agri Machineries',
  'Motors Agri Machineries',
  'Motors Agri Machineries',
  'Motors Agri Machineries',
  'Motors Agri Machineries',
  'Agri Machineries',
  'My Portfolio',
  'Tractor',
  'PT, DE, SP & ME',
  'Power Solution & Medical Equipment',
  'Yamaha',
  'Tractor',
  'CEAT TIRE',
  'Motors Agri Machineries',
  'Power Tiller',
  'Motors Marketing',
  'Yamaha',
];

const _zones = [
  'Dhaka Central',
  'Dhaka East',
  'Dhaka West',
  'Chittagong',
  'Sylhet',
  'Bogura',
  'Rajshahi',
  'Rangpur',
];

Profile staticProfileForLevel(int level) =>
    staticOrg[(level.clamp(1, 17)) - 1];

/// Map a free-text designation from the API onto one of the 17 levels.
/// Unknown designations default to level 17 (field executive view).
int designationToLevel(String designation) {
  final d = designation.trim().toLowerCase();
  
  // Exact or exact-contains checks for high tiers:
  if (d.contains('managing director') || d.contains('dmd') || d.contains('deputy managing director')) {
    if (d.contains('deputy')) {
      return 2;
    }
    return 1;
  }
  if (d.contains('executive director')) {
    return 3;
  }
  if (d.contains('cbo') || d.contains('chief business officer')) {
    return 4;
  }
  if (d.contains('business director') || d.contains('dbd')) {
    if (d.contains('deputy') || d.contains('dbd')) {
      return 6;
    }
    return 5;
  }
  if (d.contains('business manager')) {
    return 7;
  }
  if (d.contains('sr. gm') || d.contains('senior gm') || d.contains('sr. general manager')) {
    return 8;
  }
  if (d.contains('general manager') || d.contains('gm')) {
    return 9;
  }
  if (d.contains('marketing manager') || d.contains('dgm')) {
    return 10;
  }
  
  // L11: AMM (Assistant Marketing Manager)
  if (d.contains('assistant marketing manager') || d.contains('asst. marketing manager') || d.contains('amm')) {
    return 11;
  }
  
  // L12: Sr. PM / Sr. BM / Senior Product Manager / Senior Brand Manager
  if (d.contains('sr. pm') || d.contains('sr. bm') || d.contains('senior product manager') || d.contains('senior brand manager') || d.contains('sr. pm/sr. bm')) {
    return 12;
  }
  
  // L15: Assistant Manager / Asst. Manager
  if (d.contains('assistant manager') || d.contains('asst. manager') || d.contains('apm') || d.contains('abm') || d.contains('asst. product manager')) {
    return 15;
  }
  
  // L14: Deputy Manager / Dy. Manager / Deputy Product Manager / Dy. Product Manager
  if (d.contains('deputy manager') || d.contains('dy. manager') || d.contains('deputy product manager') || d.contains('dy. product manager') || d.contains('deputy')) {
    return 14;
  }

  // L16: Senior Executive / Sr. Executive / Sr. PE / Sr. PDE / Sr. BDE / Sr. BE / Sr. Ex / Sr. Exe / Sr. BPE / Sr.SPE / Sr. MIE / Sr. Planning Executive / Planning Executive
  if (d.contains('senior executive') || d.contains('sr. executive') || d.contains('sr.pe') || d.contains('sr. pde') || 
      d.contains('sr. bde') || d.contains('sr. be') || d.contains('sr. ex') || d.contains('sr. exe') || 
      d.contains('sr. bpe') || d.contains('sr.spe') || d.contains('sr. mie') || d.contains('planning executive')) {
    return 16;
  }
  
  // L13: Manager / PM / BM / NDM / Sr. Manager
  if (d.contains('manager') || d.contains('product manager') || d.contains('brand manager') || d.contains('ndm')) {
    return 13;
  }

  // L17: Product Executive / Executive / PE / PDE / BDE / BE / MCE / Jr. Executive / Jr. TE / Jr. Exe / LO / TE / Office
  return 17;
}

/// Everyone below `level` in the demo chain.
List<Profile> staticDownlineOf(int level) =>
    staticOrg.where((p) => p.roleLevel > level).toList();

List<Profile> staticDirectReportsOf(int level) =>
    staticOrg.where((p) => p.roleLevel == level + 1).toList();

/// 6 trailing months of KPIs per person: target scales with level,
/// achievement is deterministic per (user, period).
List<Kpi> staticKpisFor(String userId, int level) {
  final now = DateTime.now();
  return [
    for (var n = 5; n >= 0; n--)
      () {
        final month = DateTime(now.year, now.month - n, 1);
        final period =
            '${month.year}-${month.month.toString().padLeft(2, '0')}';
        final target = (40 + level * 5).toDouble();
        final achieved =
            (target * (0.62 + 0.5 * _rand('$userId-$period'))).roundToDouble();
        return Kpi(
          id: 'kpi-$userId-$period',
          userId: userId,
          metric: 'Sales (BDT lakh)',
          target: target,
          achieved: achieved,
          period: period,
        );
      }(),
  ];
}

List<Kpi> staticDownlineKpis(int level) => [
      for (final p in staticDownlineOf(level))
        ...staticKpisFor(p.id, p.roleLevel),
    ];

/// Attendance today for the demo downline — field levels are on duty,
/// one absentee for realism.
List<Attendance> staticDownlineAttendanceToday(int level) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return [
    for (final p in staticDownlineOf(level))
      if (p.roleLevel != 15) // APM hasn't checked in yet (demo)
        Attendance(
          id: 'att-${p.id}-today',
          userId: p.id,
          date: today,
          checkIn: today.add(Duration(
              hours: 8, minutes: 50 + (_rand(p.id) * 25).round())),
          checkOut: null,
        ),
  ];
}

/// 14-day attendance history for one demo member (Fri/Sat off).
List<Attendance> staticAttendanceHistory(String userId) {
  final now = DateTime.now();
  return [
    for (var n = 13; n >= 0; n--)
      () {
        final day = DateTime(now.year, now.month, now.day - n);
        final weekend = day.weekday == DateTime.friday ||
            day.weekday == DateTime.saturday;
        final absent = _rand('$userId-${day.day}') > 0.9;
        if (weekend || absent) return null;
        return Attendance(
          id: 'att-$userId-${day.day}',
          userId: userId,
          date: day,
          checkIn: day.add(Duration(
              hours: 8, minutes: 48 + (_rand('$userId-i${day.day}') * 30).round())),
          checkOut: n == 0
              ? null
              : day.add(Duration(
                  hours: 18,
                  minutes: (_rand('$userId-o${day.day}') * 20).round())),
        );
      }(),
  ].whereType<Attendance>().toList();
}

/// The 8-slot timed day used by the demo field members.
const _daySlots = [
  ('09:00', '10:00', 'reporting', 'Morning reporting & plan', 'ACI Centre', 0),
  ('10:00', '11:30', 'market_visit', 'Dealer visit — Bashundhara', 'Bashundhara', 0),
  ('11:30', '13:00', 'sales_call', 'Sales calls — prospect follow-ups', 'Field', 0),
  ('13:00', '13:45', 'other', 'Lunch break', 'ACI Centre', 45),
  ('13:45', '15:30', 'meeting', 'Team sync meeting', 'ACI Centre', 0),
  ('15:30', '17:00', 'service_followup', 'Service follow-up — workshop', 'Tejgaon', 0),
  ('17:00', '17:15', 'other', 'Tea break', 'ACI Centre', 15),
  ('17:15', '18:00', 'reporting', 'EOD report submission', 'ACI Centre', 0),
];

DateTime _at(DateTime day, String hhmm) {
  final parts = hhmm.split(':');
  return DateTime(
      day.year, day.month, day.day, int.parse(parts[0]), int.parse(parts[1]));
}

/// Today's activities for one demo field member, truncated to "now" so the
/// feed looks live.
List<Activity> staticActivitiesToday(String userId) {
  final now = DateTime.now();
  final day = DateTime(now.year, now.month, now.day);
  final out = <Activity>[];
  var i = 0;
  for (final s in _daySlots) {
    final start = _at(day, s.$1);
    if (start.isAfter(now)) break;
    out.add(Activity(
      id: 'act-$userId-$i',
      userId: userId,
      type: s.$3,
      title: s.$4,
      startedAt: start,
      endedAt: _at(day, s.$2),
      location: s.$5,
      breakMinutes: s.$6,
    ));
    i++;
  }
  return out;
}

/// Today's activity feed across the demo downline (field levels only).
List<Activity> staticDownlineActivitiesToday(int level) => [
      for (final p in staticDownlineOf(level))
        if (p.roleLevel > observerMaxLevel)
          ...staticActivitiesToday(p.id),
    ]..sort((a, b) => b.startedAt.compareTo(a.startedAt));

/// Cascading demo tasks (each level assigns down to the next).
List<TaskItem> staticOrgTasks() {
  final now = DateTime.now();
  const titles = [
    'Quarterly marketing strategy review',
    'Motors division P&L summary',
    'Dealer network expansion plan',
    'Sales incentive scheme draft',
    'Zone-wise sales target split',
    'Competitor pricing snapshot',
    'Trade fair participation plan',
    'Chittagong campaign brief',
    'Monthly media spend report',
    'Product brochure refresh',
    'SKU-level demand forecast',
    'Field visit plan — Bogura',
    'Dealer stock audit',
    'Farmer meet arrangement',
    'Demo tractor logistics',
    'Weekly activity report',
  ];
  const priorities = ['high', 'medium', 'urgent', 'low'];
  const statuses = ['todo', 'in_progress', 'todo', 'done'];
  return [
    for (var l = 1; l <= 16; l++)
      TaskItem(
        id: 'static-task-$l',
        title: titles[l - 1],
        description: 'Demo task cascading from L$l to L${l + 1}.',
        status: statuses[l % statuses.length],
        priority: priorities[l % priorities.length],
        assignerId: staticProfileForLevel(l).id,
        assigneeId: staticProfileForLevel(l + 1).id,
        dueDate: now.add(Duration(days: (l % 7) - 1)),
        createdAt: now.subtract(Duration(days: l % 5)),
      ),
  ];
}

/// Trainings shown on /growth (static).
List<Training> staticTrainingsFor(String userId) {
  final now = DateTime.now();
  return [
    Training(
        id: 'trn-$userId-1',
        userId: userId,
        title: 'Product knowledge — Sonalika tractors',
        status: 'completed',
        completedDate: now.subtract(const Duration(days: 40))),
    Training(
        id: 'trn-$userId-2',
        userId: userId,
        title: 'Field sales fundamentals',
        status: 'completed',
        completedDate: now.subtract(const Duration(days: 90))),
    Training(
        id: 'trn-$userId-3',
        userId: userId,
        title: 'CRM basics',
        status: 'planned'),
  ];
}

/// Feedback received, shown on /growth (static, from the demo upline).
List<FeedbackItem> staticFeedbackFor(String userId, int level) {
  final now = DateTime.now();
  final boss = staticProfileForLevel(level > 1 ? level - 1 : 1);
  final boss2 = staticProfileForLevel(level > 2 ? level - 2 : 1);
  return [
    FeedbackItem(
      id: 'fb-$userId-1',
      fromUser: boss.id,
      toUser: userId,
      rating: 5,
      comment: 'Excellent dealer coverage this month — keep the momentum.',
      createdAt: now.subtract(const Duration(days: 2)),
    ),
    FeedbackItem(
      id: 'fb-$userId-2',
      fromUser: boss2.id,
      toUser: userId,
      rating: 4,
      comment: 'Good reporting discipline. Tighten EOD submission time.',
      createdAt: now.subtract(const Duration(days: 6)),
    ),
  ];
}

/// Current-month average achievement % for a demo member.
double? staticCurrentKpiPct(String userId, int level) {
  final kpis = staticKpisFor(userId, level)
      .where((k) => k.period == currentPeriod() && k.target > 0);
  if (kpis.isEmpty) return null;
  return kpis.map((k) => k.pct).reduce((a, b) => a + b) / kpis.length;
}

List<Profile> loadAllEmployees() {
  try {
    final parsed = jsonDecode(empDataJsonRaw) as List;
    return parsed.map((e) {
      final map = e as Map<String, dynamic>;
      final des = map['Designation'] ?? '';
      return Profile(
        id: map['Employee ID'] ?? map['id'].toString(),
        fullName: map['Name'] ?? '',
        employeeId: map['Employee ID'] ?? '',
        email: 'aci-${map['Employee ID']}@aci-bd.com',
        roleLevel: designationToLevel(des),
        designation: des,
        department: map['Team'] ?? map['Portfolio'] ?? '',
        zone: 'Dhaka',
        managerId: map['Supervisor ID'] ?? '',
        phone: '',
      );
    }).toList();
  } catch (_) {
    return [];
  }
}
