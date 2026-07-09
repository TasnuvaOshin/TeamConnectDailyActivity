import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/static_data.dart';
import '../hierarchy.dart';
import '../models/activity.dart';
import '../models/attendance.dart';
import '../models/kpi.dart';
import '../models/profile.dart';
import '../models/task.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../theme.dart';
import '../util/fmt.dart';
import '../widgets/pills.dart';
import '../widgets/quick_assign_dialog.dart';

/// STATIC: member profiles come from the demo org — the third-party API
/// has no directory/lookup endpoint.
final _memberProvider =
    FutureProvider.family<Profile?, String>((ref, userId) async {
  for (final p in staticOrg) {
    if (p.id == userId) return p;
  }
  return null;
});

/// STATIC: attendance, activities, tasks and KPIs for a member are all
/// generated demo data (no per-member API access exists).
final _memberBundleProvider =
    FutureProvider.family<_MemberBundle, String>((ref, userId) async {
  final member = await ref.watch(_memberProvider(userId).future);
  final level = member?.roleLevel ?? 17;
  final delegated = ref.watch(delegatedTasksProvider);
  return _MemberBundle(
    attendance: staticAttendanceHistory(userId),
    activities: level > observerMaxLevel
        ? staticActivitiesToday(userId)
        : const [],
    tasks: [
      ...delegated.where((t) => t.assigneeId == userId),
      ...staticOrgTasks().where((t) => t.assigneeId == userId),
    ],
    kpis: staticKpisFor(userId, level),
  );
});

class _MemberBundle {
  final List<Attendance> attendance;
  final List<Activity> activities;
  final List<TaskItem> tasks;
  final List<Kpi> kpis;
  _MemberBundle({
    required this.attendance,
    required this.activities,
    required this.tasks,
    required this.kpis,
  });
}

class TeamMemberScreen extends ConsumerWidget {
  final String userId;
  const TeamMemberScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberAsync = ref.watch(_memberProvider(userId));
    final bundleAsync = ref.watch(_memberBundleProvider(userId));

    return memberAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (p) {
        if (p == null) return const Center(child: Text('Member not found'));
        return bundleAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (b) => _Body(profile: p, bundle: b),
        );
      },
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  final Profile profile;
  final _MemberBundle bundle;
  const _Body({required this.profile, required this.bundle});
  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  int _rating = 0;
  final _feedback = TextEditingController();
  bool _sending = false;

  Profile get profile => widget.profile;
  _MemberBundle get bundle => widget.bundle;

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(myProfileProvider).valueOrNull;
    final viewerIsBoss =
        me != null && isObserver(me.roleLevel) && me.id != profile.id;

    final open = bundle.tasks.where((t) => t.isOpen).toList();
    final overdue = open
        .where((t) =>
            t.dueDate != null && t.dueDate!.isBefore(DateTime.now()))
        .length;
    final done = bundle.tasks.length - open.length;
    final donePct = bundle.tasks.isEmpty
        ? null
        : (done * 100 / bundle.tasks.length).round();

    final period = currentPeriod();
    final current = bundle.kpis
        .where((k) => k.period == period && k.target > 0)
        .toList();
    final kpiPct = current.isEmpty
        ? null
        : (current.map((k) => k.pct).reduce((a, b) => a + b) /
                current.length)
            .round();

    final days = _last14Days();
    final present = bundle.attendance.where((a) => a.checkIn != null).length;

    final today = DateTime.now();
    final todaysActivities = bundle.activities
        .where((a) =>
            a.startedAt.year == today.year &&
            a.startedAt.month == today.month &&
            a.startedAt.day == today.day)
        .toList()
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Back link
        InkWell(
          onTap: () => context.go('/team'),
          child: const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text('← Team',
                style: TextStyle(fontSize: 11, color: AppColors.mute)),
          ),
        ),
        // Profile hero (§6.2)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [AppColors.forestDeep, AppColors.forest]),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(38),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.white.withAlpha(64), width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(profile.initials,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile.fullName,
                          style: display(
                              size: 20,
                              weight: FontWeight.w800,
                              color: Colors.white)),
                      Text('L${profile.roleLevel} · ${profile.designation}',
                          style: TextStyle(
                              color: Colors.white.withAlpha(204),
                              fontSize: 12)),
                      const SizedBox(height: 2),
                      Row(children: [
                        Text(
                            'ID ${profile.employeeId ?? '—'} · ${profile.department ?? '—'} · ',
                            style: TextStyle(
                                color: Colors.white.withAlpha(153),
                                fontSize: 11)),
                        const Icon(Icons.place_outlined,
                            size: 11, color: Colors.white70),
                        Text(profile.zone ?? '—',
                            style: TextStyle(
                                color: Colors.white.withAlpha(153),
                                fontSize: 11)),
                      ]),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                _bossStat('KPI %', kpiPct == null ? '—' : '$kpiPct%'),
                const SizedBox(width: 8),
                _bossStat('Done %', donePct == null ? '—' : '$donePct%'),
                const SizedBox(width: 8),
                _bossStat('Open', '${open.length}',
                    warn: overdue > 0),
                const SizedBox(width: 8),
                _bossStat('Present', '$present/14'),
              ]),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (profile.email != null)
                  _contactButton(Icons.mail_outline, 'Email',
                      () => launchUrl(Uri.parse('mailto:${profile.email}'))),
                if (profile.phone != null) ...[
                  _contactButton(Icons.phone_outlined, 'Call',
                      () => launchUrl(Uri.parse('tel:${profile.phone}'))),
                  _contactButton(Icons.sms_outlined, 'SMS',
                      () => launchUrl(Uri.parse('sms:${profile.phone}'))),
                  _contactButton(
                      Icons.chat_outlined,
                      'WhatsApp',
                      () => launchUrl(
                          Uri.parse(
                              'https://wa.me/${profile.phone!.replaceAll(RegExp(r'[^0-9]'), '')}'),
                          mode: LaunchMode.externalApplication)),
                ],
              ]),
            ],
          ),
        ),
        // Boss actions (§6.3)
        if (viewerIsBoss) ...[
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => showQuickAssignDialog(context, ref,
                    presetAssignee: profile),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Assign task'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: _NudgeButton(target: profile)),
          ]),
        ],
        const SizedBox(height: 14),
        // Attendance · last 14 days (§6.4)
        _card(
          title: 'Attendance · last 14 days',
          trailing: Text('$present present',
              style: const TextStyle(fontSize: 11, color: AppColors.mute)),
          child: SizedBox(
            height: 64,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final d in days) ...[
                  Expanded(child: _dayBar(d)),
                  const SizedBox(width: 3),
                ],
              ],
            ),
          ),
        ),
        // Target vs achieved (§6.5)
        if (bundle.kpis.isNotEmpty) ...[
          const SizedBox(height: 14),
          _card(
            title: 'Target vs Achieved',
            child: Column(children: [
              SizedBox(height: 180, child: _targetChart()),
              const SizedBox(height: 14),
              SizedBox(height: 70, child: _pctLineChart()),
            ]),
          ),
        ],
        // Open tasks (§6.6)
        if (open.isNotEmpty) ...[
          const SizedBox(height: 14),
          _card(
            title: 'Open tasks · ${open.length}',
            trailing: overdue > 0
                ? Pill('$overdue overdue', color: AppColors.red)
                : null,
            child: Column(children: [
              for (final t in open)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    Expanded(
                      child: Text(t.title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                    ),
                    PriorityPill(t.priority),
                    if (t.dueDate != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        fmtDeadline(t.dueDate!),
                        style: TextStyle(
                          fontSize: 11,
                          color: t.dueDate!.isBefore(DateTime.now())
                              ? AppColors.destructive
                              : AppColors.mute,
                          fontWeight: t.dueDate!.isBefore(DateTime.now())
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                    if (viewerIsBoss)
                      IconButton(
                        tooltip: 'Send reminder',
                        icon: const Icon(Icons.notifications_none,
                            size: 16, color: AppColors.forest),
                        onPressed: () => _sendReminder(t.id),
                      ),
                  ]),
                ),
            ]),
          ),
        ],
        // Today's timeline (§6.7)
        if (todaysActivities.isNotEmpty) ...[
          const SizedBox(height: 14),
          _card(
            title: "Today's timeline",
            child: Column(children: [
              for (final a in todaysActivities.take(8))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    SizedBox(
                        width: 44,
                        child: Text(fmtClock(a.startedAt),
                            style: mono(size: 12))),
                    Container(
                      width: 3,
                      height: 28,
                      decoration: BoxDecoration(
                        color:
                            a.isBreak ? AppColors.amber : AppColors.moss,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.title,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                          if (a.location != null)
                            Text(a.location!,
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.mute)),
                        ],
                      ),
                    ),
                  ]),
                ),
            ]),
          ),
        ],
        // Recent activity (§6.8)
        if (bundle.activities.isNotEmpty) ...[
          const SizedBox(height: 14),
          _card(
            title: 'Recent activity',
            child: Column(children: [
              for (final a in bundle.activities.take(12))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    SizedBox(
                      width: 42,
                      child: Text(
                          DateFormat('MM-dd').format(a.startedAt),
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.mute)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.forestDeep.withAlpha(20),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(categoryLabel(a.type),
                          style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: AppColors.forestDeep)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(a.title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12)),
                    ),
                    if (a.location != null)
                      Text(a.location!,
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.mute)),
                  ]),
                ),
            ]),
          ),
        ],
        // Leave feedback (§6.9)
        const SizedBox(height: 14),
        _card(
          title: 'Leave feedback',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 34, minHeight: 34),
                    icon: Icon(
                      i <= _rating ? Icons.star : Icons.star_border,
                      color: i <= _rating
                          ? const Color(0xFF8FCC3F)
                          : AppColors.mute,
                      size: 24,
                    ),
                    onPressed: () => setState(() => _rating = i),
                  ),
              ]),
              const SizedBox(height: 8),
              TextField(
                controller: _feedback,
                maxLines: 3,
                onChanged: (_) => setState(() {}),
                decoration:
                    const InputDecoration(hintText: 'Your feedback…'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _feedback.text.trim().isEmpty || _sending
                    ? null
                    : _sendFeedback,
                child: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Send feedback'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _sendReminder(String taskId) async {
    // STATIC: the API has no reminder/comment endpoint — UI feedback only.
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Reminder sent (demo — not synced)')));
    }
  }

  Future<void> _sendFeedback() async {
    // STATIC: the API has no feedback endpoint — UI feedback only.
    setState(() => _sending = true);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() {
        _sending = false;
        _rating = 0;
        _feedback.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Feedback sent ⭐ (demo — not synced)')));
    }
  }

  List<DateTime> _last14Days() => [
        for (var i = 13; i >= 0; i--)
          DateTime.now().subtract(Duration(days: i)),
      ];

  Widget _dayBar(DateTime d) {
    final att = bundle.attendance.where((a) =>
        a.date.year == d.year &&
        a.date.month == d.month &&
        a.date.day == d.day);
    final presentDay = att.any((a) => a.checkIn != null);
    // Fri/Sat weekends in Bangladesh.
    final weekend =
        d.weekday == DateTime.friday || d.weekday == DateTime.saturday;
    final color = presentDay
        ? AppColors.forestDeep
        : weekend
            ? const Color(0xFFE2E8F0)
            : const Color(0xFFFECACA);
    final status = presentDay
        ? 'Present'
        : weekend
            ? 'Weekend'
            : 'Absent';
    return Tooltip(
      message: '${DateFormat('EEE d MMM').format(d)} · $status',
      child: Container(
        height: presentDay ? 56 : 34,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  Widget _bossStat(String label, String value, {bool warn = false}) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: warn
                ? AppColors.amber.withAlpha(64)
                : Colors.white.withAlpha(38),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(children: [
            Text(value,
                style: display(
                    size: 15, weight: FontWeight.w800, color: Colors.white)),
            Text(label.toUpperCase(),
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 8,
                    letterSpacing: 0.8)),
          ]),
        ),
      );

  Widget _contactButton(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: Colors.white.withAlpha(38),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }

  Widget _card({required String title, required Widget child, Widget? trailing}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
              ),
              if (trailing != null) trailing,
            ]),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  /// Grouped bars: Target (moss) vs Achieved (forest-deep) per period.
  Widget _targetChart() {
    final periods = bundle.kpis.map((k) => k.period).toSet().toList()..sort();
    final recent =
        periods.length > 6 ? periods.sublist(periods.length - 6) : periods;
    final data = <(String, double, double)>[];
    for (final p in recent) {
      final rows = bundle.kpis.where((k) => k.period == p);
      final target = rows.fold<double>(0, (s, k) => s + k.target.toDouble());
      final achieved =
          rows.fold<double>(0, (s, k) => s + k.achieved.toDouble());
      data.add((periodLabel(p), target, achieved));
    }
    return BarChart(
      BarChartData(
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: AppColors.border, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.round();
                if (i < 0 || i >= data.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(data[i].$1,
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.mute)),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < data.length; i++)
            BarChartGroupData(x: i, barsSpace: 3, barRods: [
              BarChartRodData(
                  toY: data[i].$2,
                  color: AppColors.moss,
                  width: 9,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3))),
              BarChartRodData(
                  toY: data[i].$3,
                  color: AppColors.forestDeep,
                  width: 9,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3))),
            ]),
        ],
      ),
    );
  }

  /// Tiny % achievement line — lime line, forest-deep dots.
  Widget _pctLineChart() {
    final periods = bundle.kpis.map((k) => k.period).toSet().toList()..sort();
    final recent =
        periods.length > 6 ? periods.sublist(periods.length - 6) : periods;
    final spots = <FlSpot>[];
    for (var i = 0; i < recent.length; i++) {
      final rows =
          bundle.kpis.where((k) => k.period == recent[i] && k.target > 0);
      if (rows.isEmpty) continue;
      final pct =
          rows.map((k) => k.pct).reduce((a, b) => a + b) / rows.length;
      spots.add(FlSpot(i.toDouble(), pct));
    }
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineBarsData: [
          LineChartBarData(
            isCurved: true,
            color: const Color(0xFF8FCC3F),
            barWidth: 2,
            dotData: FlDotData(
              show: true,
              getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: 2.6,
                  color: AppColors.forestDeep,
                  strokeColor: Colors.white,
                  strokeWidth: 1),
            ),
            spots: spots,
          ),
        ],
      ),
    );
  }
}

/// Quick nudge dropdown — check-in / update / meeting (§6.3).
class _NudgeButton extends ConsumerWidget {
  final Profile target;
  const _NudgeButton({required this.target});

  static const _nudges = {
    'check-in': '🔔 Nudge: please check in at the ACI Centre.',
    'update': '🔔 Nudge: please share a quick status update.',
    'meeting': '🔔 Nudge: please join the team meeting.',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      onSelected: (key) {
        // STATIC: the API has no nudge/feedback endpoint — UI only.
        // (_nudges keeps the documented copy strings for the demo toast.)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${_nudges[key]!} — sent (demo, not synced)')));
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'check-in', child: Text('Nudge · Check in')),
        PopupMenuItem(value: 'update', child: Text('Nudge · Status update')),
        PopupMenuItem(value: 'meeting', child: Text('Nudge · Meeting')),
      ],
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none,
                size: 16, color: AppColors.forestDeep),
            SizedBox(width: 6),
            Text('Quick nudge',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.forestDeep)),
          ],
        ),
      ),
    );
  }
}
