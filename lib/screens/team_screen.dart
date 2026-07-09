import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../widgets/level_avatar.dart';
import '../widgets/pills.dart';

/// Per-member live stats computed from downline providers.
class _MemberStats {
  final bool onDuty;
  final int logsToday;
  final int openTasks;
  final double? kpiPct;
  const _MemberStats({
    this.onDuty = false,
    this.logsToday = 0,
    this.openTasks = 0,
    this.kpiPct,
  });
}

Map<String, _MemberStats> _buildStats({
  required List<Profile> members,
  required List<Attendance> attendance,
  required List<Activity> activities,
  required List<TaskItem> openTasks,
  required List<Kpi> kpis,
}) {
  final period = currentPeriod();
  final out = <String, _MemberStats>{};
  for (final p in members) {
    final att = attendance.where((a) => a.userId == p.id).toList();
    final myKpis =
        kpis.where((k) => k.userId == p.id && k.period == period && k.target > 0);
    double? pct;
    if (myKpis.isNotEmpty) {
      pct = myKpis.map((k) => k.pct).reduce((a, b) => a + b) / myKpis.length;
    }
    out[p.id] = _MemberStats(
      onDuty: att.any((a) => a.checkIn != null && a.checkOut == null),
      logsToday: activities.where((a) => a.userId == p.id).length,
      openTasks: openTasks.where((t) => t.assigneeId == p.id).length,
      kpiPct: pct,
    );
  }
  return out;
}

class TeamScreen extends ConsumerStatefulWidget {
  const TeamScreen({super.key});
  @override
  ConsumerState<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends ConsumerState<TeamScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(myProfileProvider).valueOrNull;
    final observer = isObserver(profile?.roleLevel);
    final downline = ref.watch(downlineProvider).valueOrNull ?? const <Profile>[];
    final direct =
        ref.watch(directReportsProvider).valueOrNull ?? const <Profile>[];
    final att = ref.watch(downlineAttendanceTodayProvider).valueOrNull ??
        const <Attendance>[];
    final acts = ref.watch(downlineActivitiesTodayProvider).valueOrNull ??
        const <Activity>[];
    final openTasks =
        ref.watch(downlineOpenTasksProvider).valueOrNull ?? const <TaskItem>[];
    final kpis = ref.watch(downlineKpisProvider).valueOrNull ?? const <Kpi>[];

    final stats = _buildStats(
      members: downline,
      attendance: att,
      activities: acts,
      openTasks: openTasks,
      kpis: kpis,
    );

    final onDuty = stats.values.where((s) => s.onDuty).length;
    final logging = stats.values.where((s) => s.logsToday > 0).length;
    final kpiVals = stats.values
        .where((s) => s.kpiPct != null)
        .map((s) => s.kpiPct!)
        .toList();
    final avgKpi = kpiVals.isEmpty
        ? null
        : kpiVals.reduce((a, b) => a + b) / kpiVals.length;

    final q = _search.trim().toLowerCase();
    final searchResults = q.isEmpty
        ? const <Profile>[]
        : downline
            .where((p) =>
                p.fullName.toLowerCase().contains(q) ||
                p.designation.toLowerCase().contains(q) ||
                (p.zone ?? '').toLowerCase().contains(q))
            .toList();

    final tabCount = observer ? 3 : 2;

    return DefaultTabController(
      length: tabCount,
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(downlineProvider);
          ref.invalidate(downlineAttendanceTodayProvider);
          ref.invalidate(downlineActivitiesTodayProvider);
          ref.invalidate(downlineOpenTasksProvider);
          ref.invalidate(downlineKpisProvider);
          await Future<void>.delayed(const Duration(milliseconds: 250));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('My Team',
                style: display(
                    size: 24,
                    weight: FontWeight.w800,
                    color: AppColors.forestDeep)),
            Text(
              observer
                  ? 'Command view — everyone reporting under you.'
                  : 'Drill down through your team.',
              style: const TextStyle(fontSize: 12, color: AppColors.mute),
            ),
            const SizedBox(height: 14),
            // Snapshot strip (§5.1)
            Row(children: [
              Expanded(
                  child: _Snap(
                      label: 'Team',
                      value: '${downline.length}',
                      icon: Icons.groups_2_outlined,
                      tone: AppColors.forest)),
              const SizedBox(width: 8),
              Expanded(
                  child: _Snap(
                      label: 'On duty',
                      value: '$onDuty',
                      icon: Icons.wifi_tethering,
                      tone: AppColors.forestSoft)),
              const SizedBox(width: 8),
              Expanded(
                  child: _Snap(
                      label: 'Logging',
                      value: '$logging',
                      icon: Icons.schedule_outlined,
                      tone: AppColors.moss)),
              const SizedBox(width: 8),
              Expanded(
                  child: _Snap(
                      label: 'Avg KPI',
                      value: avgKpi == null ? '—' : '${avgKpi.round()}%',
                      icon: Icons.speed,
                      tone: AppColors.forest)),
            ]),
            const SizedBox(height: 12),
            // Search (§5.2)
            TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: const InputDecoration(
                prefixIcon:
                    Icon(Icons.search, size: 18, color: AppColors.mute),
                hintText: 'Search name, role, or zone…',
              ),
            ),
            const SizedBox(height: 14),
            if (q.isNotEmpty) ...[
              if (searchResults.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('No matches.',
                        style:
                            TextStyle(fontSize: 13, color: AppColors.mute)),
                  ),
                ),
              for (final p in searchResults) ...[
                _PersonCard(profile: p, stats: stats[p.id]),
                const SizedBox(height: 8),
              ],
            ] else ...[
              TabBar(tabs: [
                if (observer) const Tab(text: 'Teams'),
                const Tab(text: 'Org tree'),
                const Tab(text: 'Roster'),
              ]),
              const SizedBox(height: 12),
              SizedBox(
                height: MediaQuery.of(context).size.height,
                child: TabBarView(children: [
                  if (observer)
                    _TeamsView(
                        leads: direct, downline: downline, stats: stats),
                  _OrgTreeView(
                      roots: direct, downline: downline, stats: stats),
                  _RosterView(members: downline, stats: stats),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Snap extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color tone;
  const _Snap(
      {required this.label,
      required this.value,
      required this.icon,
      required this.tone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: tone.withAlpha(31),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 13, color: tone),
          ),
          const SizedBox(height: 8),
          Text(value, style: display(size: 18, weight: FontWeight.w800)),
          Text(label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 8.5,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mute)),
        ],
      ),
    );
  }
}

/* ───────────── Teams view (observers) — §5 TeamCard ───────────── */

class _TeamsView extends StatefulWidget {
  final List<Profile> leads;
  final List<Profile> downline;
  final Map<String, _MemberStats> stats;
  const _TeamsView(
      {required this.leads, required this.downline, required this.stats});
  @override
  State<_TeamsView> createState() => _TeamsViewState();
}

class _TeamsViewState extends State<_TeamsView> {
  final _expanded = <String>{};

  List<Profile> _teamOf(Profile lead) {
    final acc = <Profile>[];
    final queue = [lead.id];
    while (queue.isNotEmpty) {
      final id = queue.removeAt(0);
      for (final p in widget.downline) {
        if (p.managerId == id) {
          acc.add(p);
          queue.add(p.id);
        }
      }
    }
    acc.sort((a, b) => a.roleLevel.compareTo(b.roleLevel));
    return acc;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.leads.isEmpty) {
      return const Center(
          child: Text('No direct reports yet.',
              style: TextStyle(color: AppColors.mute)));
    }
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        for (final lead in widget.leads) ...[
          _teamCard(lead),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _teamCard(Profile lead) {
    final members = _teamOf(lead);
    final open = _expanded.contains(lead.id);
    final leadStats = widget.stats[lead.id] ?? const _MemberStats();

    final teamIds = [lead.id, ...members.map((m) => m.id)];
    var teamOnDuty = 0;
    var teamLogs = 0;
    var teamTasks = 0;
    final kpiVals = <double>[];
    for (final id in teamIds) {
      final s = widget.stats[id];
      if (s == null) continue;
      if (s.onDuty) teamOnDuty++;
      teamLogs += s.logsToday;
      teamTasks += s.openTasks;
      if (s.kpiPct != null) kpiVals.add(s.kpiPct!);
    }
    final teamKpi = kpiVals.isEmpty
        ? null
        : kpiVals.reduce((a, b) => a + b) / kpiVals.length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [AppColors.forestDeep, AppColors.forest]),
            borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
          ),
          child: Column(children: [
            Row(children: [
              InkWell(
                onTap: () => context.go('/team/${lead.id}'),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(38),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(lead.initials,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(lead.fullName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14)),
                      ),
                      if (leadStats.onDuty) ...[
                        const SizedBox(width: 6),
                        const OnDutyDot(size: 6),
                      ],
                    ]),
                    const SizedBox(height: 2),
                    Row(children: [
                      const Icon(Icons.layers,
                          size: 11, color: Colors.white70),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          'L${lead.roleLevel} · ${lead.designation}'
                          '${lead.zone != null ? ' · ${lead.zone}' : ''}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
              Material(
                color: Colors.white.withAlpha(38),
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => setState(() =>
                      open ? _expanded.remove(lead.id) : _expanded.add(lead.id)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(open ? 'Hide' : 'View',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                      Icon(open ? Icons.expand_more : Icons.chevron_right,
                          size: 15, color: Colors.white),
                    ]),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _teamStat('Size', '${members.length + 1}'),
              _teamStat('On duty', '$teamOnDuty'),
              _teamStat('Logs', '$teamLogs'),
              _teamStat(
                  'KPI', teamKpi == null ? '—' : '${teamKpi.round()}%'),
            ]),
            if (teamTasks > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(26),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.list_alt,
                      size: 12, color: Colors.white70),
                  const SizedBox(width: 5),
                  Text('$teamTasks open tasks across team',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 11)),
                ]),
              ),
            ],
          ]),
        ),
        if (open)
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(children: [
              if (members.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(10),
                  child: Text('No subordinates under this lead.',
                      style:
                          TextStyle(fontSize: 12, color: AppColors.mute)),
                ),
              for (final m in members) ...[
                _PersonCard(profile: m, stats: widget.stats[m.id]),
                const SizedBox(height: 8),
              ],
            ]),
          ),
      ]),
    );
  }

  Widget _teamStat(String label, String value) => Expanded(
        child: Column(children: [
          Text(value,
              style: display(
                  size: 16, weight: FontWeight.w800, color: Colors.white)),
          Text(label.toUpperCase(),
              style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 8.5,
                  letterSpacing: 1)),
        ]),
      );
}

/* ───────────── Org tree — §5 recursive tree ───────────── */

class _OrgTreeView extends StatefulWidget {
  final List<Profile> roots;
  final List<Profile> downline;
  final Map<String, _MemberStats> stats;
  const _OrgTreeView(
      {required this.roots, required this.downline, required this.stats});
  @override
  State<_OrgTreeView> createState() => _OrgTreeViewState();
}

class _OrgTreeViewState extends State<_OrgTreeView> {
  final _openState = <String, bool>{};

  List<Profile> _childrenOf(String id) =>
      widget.downline.where((p) => p.managerId == id).toList()
        ..sort((a, b) => a.roleLevel.compareTo(b.roleLevel));

  @override
  Widget build(BuildContext context) {
    if (widget.roots.isEmpty) {
      return const Center(
          child: Text('No one reports to you yet.',
              style: TextStyle(color: AppColors.mute)));
    }
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        for (final r in widget.roots) _node(r, 0),
      ],
    );
  }

  Widget _node(Profile p, int depth) {
    final children = _childrenOf(p.id);
    // Branches open by default while depth < 3 (§5).
    final open = _openState[p.id] ?? depth < 3;
    final s = widget.stats[p.id] ?? const _MemberStats();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => context.go('/team/${p.id}'),
          child: Padding(
            padding: EdgeInsets.only(left: depth * 18.0, top: 4, bottom: 4),
            child: Row(children: [
              if (children.isNotEmpty)
                InkWell(
                  onTap: () => setState(() => _openState[p.id] = !open),
                  child: Icon(
                      open ? Icons.expand_more : Icons.chevron_right,
                      size: 18,
                      color: AppColors.mute),
                )
              else
                const SizedBox(width: 18),
              const SizedBox(width: 4),
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                    color: levelColor(p.roleLevel), shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(p.fullName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(p.designation,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.mute)),
              ),
              const Spacer(),
              if (s.onDuty) ...[
                const OnDutyDot(size: 6),
                const SizedBox(width: 8),
              ],
              if (s.kpiPct != null) ...[
                KpiPill(s.kpiPct!),
                const SizedBox(width: 4),
              ],
              if (s.openTasks > 0)
                Pill('${s.openTasks}', color: AppColors.slate),
            ]),
          ),
        ),
        if (open && children.isNotEmpty)
          Container(
            margin: EdgeInsets.only(left: depth * 18.0 + 12),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: AppColors.border, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (final c in children) _node(c, depth + 1)],
            ),
          ),
      ],
    );
  }
}

/* ───────────── Roster — §5 flat PersonCards ───────────── */

class _RosterView extends StatelessWidget {
  final List<Profile> members;
  final Map<String, _MemberStats> stats;
  const _RosterView({required this.members, required this.stats});

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return const Center(
          child: Text('No team members visible yet.',
              style: TextStyle(color: AppColors.mute)));
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: members.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) =>
          _PersonCard(profile: members[i], stats: stats[members[i].id]),
    );
  }
}

class _PersonCard extends StatelessWidget {
  final Profile profile;
  final _MemberStats? stats;
  const _PersonCard({required this.profile, this.stats});

  @override
  Widget build(BuildContext context) {
    final s = stats ?? const _MemberStats();
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go('/team/${profile.id}'),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(children: [
            LevelAvatar(profile: profile, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(profile.fullName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w600)),
                    ),
                    if (s.onDuty) ...[
                      const SizedBox(width: 6),
                      const OnDutyDot(size: 6),
                    ],
                  ]),
                  const SizedBox(height: 2),
                  Text(
                    'L${profile.roleLevel} · ${profile.designation}'
                    '${profile.zone != null ? ' · ${profile.zone}' : ''}',
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 11, color: AppColors.mute),
                  ),
                ],
              ),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (s.kpiPct != null) KpiPill(s.kpiPct!),
              const SizedBox(height: 3),
              Text('${s.openTasks} tasks · ${s.logsToday} logs',
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.mute)),
            ]),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                size: 16, color: AppColors.mute),
          ]),
        ),
      ),
    );
  }
}
