import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api/session.dart';
import '../theme.dart';

/* ═══════════════════════════════════════════════════════════
   MODELS
   ═══════════════════════════════════════════════════════════ */

String _s(dynamic v) => (v ?? '').toString().trim();
int _i(dynamic v) => v is int ? v : int.tryParse(_s(v)) ?? 0;
double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse(_s(v)) ?? 0.0;

String get _todayKey {
  final n = DateTime.now();
  return '${n.year.toString().padLeft(4, '0')}-'
      '${n.month.toString().padLeft(2, '0')}-'
      '${n.day.toString().padLeft(2, '0')}';
}

class TeamMember {
  final String empId;
  final String name;
  final String designation;
  final String location;
  final String portfolio;
  final String portfolioSub;
  final String supId;
  final bool active;

  const TeamMember({
    required this.empId,
    required this.name,
    required this.designation,
    required this.location,
    required this.portfolio,
    required this.portfolioSub,
    required this.supId,
    required this.active,
  });

  factory TeamMember.fromJson(Map<String, dynamic> j) => TeamMember(
    empId: _s(j['emp_id']),
    name: _s(j['emp_name']),
    designation: _s(j['emp_designation']),
    location: _s(j['location']),
    portfolio: _s(j['portfolio']),
    portfolioSub: _s(j['portfolio_sub']),
    supId: _s(j['sup_id']),
    active: _s(j['acc_status']) == '1',
  );

  String get initials {
    final parts = name
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class TeamResult {
  final List<TeamMember> direct;
  final List<TeamMember> tree;
  const TeamResult({required this.direct, required this.tree});
}

/// One row from `tasks[]`.
class TaskRow {
  final String id;
  final String details;
  final String remarks;
  final String worktype;
  final String date; // yyyy-MM-dd
  final String startTime; // "1st Half" / "2nd Half"
  final bool done;
  final bool pending;
  final String doneDate;
  final String territory;

  const TaskRow({
    required this.id,
    required this.details,
    required this.remarks,
    required this.worktype,
    required this.date,
    required this.startTime,
    required this.done,
    required this.pending,
    required this.doneDate,
    required this.territory,
  });

  factory TaskRow.fromJson(Map<String, dynamic> j) => TaskRow(
    id: _s(j['id']),
    details: _s(j['details']),
    remarks: _s(j['remarks']),
    worktype: _s(j['worktype']),
    date: _s(j['date']),
    startTime: _s(j['starttime']),
    done: _s(j['done']) == '1',
    pending: _s(j['pending']) == '1',
    doneDate: _s(j['done_date']),
    territory: _s(j['visited_territory']),
  );

  /// Not done and not explicitly pending = still processing.
  bool get processing => !done && !pending;
}

class EmployeeStats {
  final String empId;
  final String name;
  final String designation;
  final String portfolio;
  final String team;
  final String supId;

  final String fromDate;
  final String toDate;

  final int totalTask;
  final int done;
  final int processing;
  final int pending;
  final double doneRate;
  final int activeDays;
  final int inactiveDays;
  final double activityRate;
  final double avgTaskPerActiveDay;
  final String? firstActivity;
  final String? lastActivity;
  final String? mostWorktype;
  final String? busiestDay;
  final int busiestDayCount;

  final List<({String worktype, int count, double ratio})> worktypeStats;
  final Map<String, int> taskPerDay;
  final List<TaskRow> tasks;

  const EmployeeStats({
    required this.empId,
    required this.name,
    required this.designation,
    required this.portfolio,
    required this.team,
    required this.supId,
    required this.fromDate,
    required this.toDate,
    required this.totalTask,
    required this.done,
    required this.processing,
    required this.pending,
    required this.doneRate,
    required this.activeDays,
    required this.inactiveDays,
    required this.activityRate,
    required this.avgTaskPerActiveDay,
    required this.firstActivity,
    required this.lastActivity,
    required this.mostWorktype,
    required this.busiestDay,
    required this.busiestDayCount,
    required this.worktypeStats,
    required this.taskPerDay,
    required this.tasks,
  });

  factory EmployeeStats.fromJson(Map<String, dynamic> j) {
    final emp = (j['employee'] as Map<String, dynamic>?) ?? const {};
    final range = (j['range'] as Map<String, dynamic>?) ?? const {};
    final sum = (j['summary'] as Map<String, dynamic>?) ?? const {};

    // task_per_day is a map when populated, [] when empty.
    final tpdRaw = j['task_per_day'];
    final tpd = <String, int>{};
    if (tpdRaw is Map) {
      tpdRaw.forEach((k, v) => tpd[_s(k)] = _i(v));
    }

    return EmployeeStats(
      empId: _s(emp['emp_id']),
      name: _s(emp['emp_name']),
      designation: _s(emp['emp_designation']),
      portfolio: _s(emp['portfolio']),
      team: _s(emp['team']),
      supId: _s(emp['sup_id']),
      fromDate: _s(range['f_date']),
      toDate: _s(range['t_date']),
      totalTask: _i(sum['total_task']),
      done: _i(sum['done']),
      processing: _i(sum['processing']),
      pending: _i(sum['pending']),
      doneRate: _d(sum['done_rate']),
      activeDays: _i(sum['active_days']),
      inactiveDays: _i(sum['inactive_days']),
      activityRate: _d(sum['activity_rate']),
      avgTaskPerActiveDay: _d(sum['avg_task_per_active_day']),
      firstActivity: _s(sum['first_activity']).isEmpty
          ? null
          : _s(sum['first_activity']),
      lastActivity: _s(sum['last_activity']).isEmpty
          ? null
          : _s(sum['last_activity']),
      mostWorktype: _s(sum['most_worktype']).isEmpty
          ? null
          : _s(sum['most_worktype']),
      busiestDay: _s(sum['busiest_day']).isEmpty
          ? null
          : _s(sum['busiest_day']),
      busiestDayCount: _i(sum['busiest_day_count']),
      worktypeStats: ((j['worktype_stats'] as List?) ?? const [])
          .map(
            (e) => (
              worktype: _s((e as Map)['worktype']),
              count: _i(e['count']),
              ratio: _d(e['ratio']),
            ),
          )
          .toList(),
      taskPerDay: tpd,
      tasks:
          ((j['tasks'] as List?) ?? const [])
              .map((e) => TaskRow.fromJson(e as Map<String, dynamic>))
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date)),
    );
  }

  /// Today-only roll-up, derived from `tasks[]` — this is what the
  /// team KPI is built from.
  DayStats get today {
    final t = tasks.where((x) => x.date == _todayKey).toList();
    final d = t.where((x) => x.done).length;
    final p = t.length - d;
    return DayStats(total: t.length, done: d, pending: p);
  }
}

/// Per-member today roll-up.
class DayStats {
  final int total;
  final int done;
  final int pending;
  const DayStats({this.total = 0, this.done = 0, this.pending = 0});

  bool get logged => total > 0;

  /// done ÷ (done + pending). Null when nothing was logged today.
  double? get kpiPct => total == 0 ? null : (done / total) * 100;
}

/* ═══════════════════════════════════════════════════════════
   PLAIN API — no providers
   ═══════════════════════════════════════════════════════════ */

class TeamApi {
  static const _base = 'https://dailyactivityapi.acipanel.com';

  static Future<TeamResult> fetchTeam(String empId) async {
    final uri = Uri.parse(
      '$_base/team',
    ).replace(queryParameters: {'id': empId});
    final r = await http.get(uri).timeout(const Duration(seconds: 25));
    if (r.statusCode != 200) throw Exception('Server error (${r.statusCode})');

    final body = jsonDecode(r.body) as Map<String, dynamic>;
    if ('${body['response']}' != '200') throw Exception('Could not load team');

    List<TeamMember> parse(String key) =>
        ((body[key] as List?) ?? const [])
            .map((e) => TeamMember.fromJson(e as Map<String, dynamic>))
            .where((m) => m.active && m.empId.isNotEmpty)
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

    return TeamResult(
      direct: parse('under_my_supervison'), // API spells it this way
      tree: parse('under_my_tree'),
    );
  }

  static Future<EmployeeStats> fetchEmployeeStats(String empId) async {
    final uri = Uri.parse(
      '$_base/employee_stats',
    ).replace(queryParameters: {'emp_id': empId});
    final r = await http.get(uri).timeout(const Duration(seconds: 25));
    if (r.statusCode != 200) throw Exception('Server error (${r.statusCode})');

    final body = jsonDecode(r.body) as Map<String, dynamic>;
    if ('${body['response']}' != '200') {
      throw Exception('Could not load stats');
    }
    return EmployeeStats.fromJson(body);
  }

  /// Fetch today's stats for many members, 6 requests at a time so we
  /// don't fire 32 sockets at once. A single failure never kills the list.
  static Future<Map<String, DayStats>> fetchTeamToday(
    List<String> empIds, {
    int concurrency = 6,
  }) async {
    final out = <String, DayStats>{};
    for (var i = 0; i < empIds.length; i += concurrency) {
      final slice = empIds.skip(i).take(concurrency);
      await Future.wait(
        slice.map((id) async {
          try {
            final stats = await fetchEmployeeStats(id);
            out[id] = stats.today;
          } catch (_) {
            out[id] = const DayStats();
          }
        }),
      );
    }
    return out;
  }
}

/* ═══════════════════════════════════════════════════════════
   TEAM SCREEN
   ═══════════════════════════════════════════════════════════ */

class TeamScreen extends StatefulWidget {
  /// Optional. Falls back to the signed-in user's emp_id.
  final String? empId;
  const TeamScreen({super.key, this.empId});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  bool _loading = true;
  bool _statsLoading = false;
  String? _error;
  String _search = '';
  bool _directOnly = true;

  TeamResult _team = const TeamResult(direct: [], tree: []);
  Map<String, DayStats> _today = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var empId = widget.empId;
      if (empId == null || empId.isEmpty) {
        final session = await SessionStore().load(); // rename if yours differs
        empId = session?.empId;
      }
      if (empId == null || empId.isEmpty) {
        throw Exception('No signed-in user found');
      }

      final team = await TeamApi.fetchTeam(empId);
      if (!mounted) return;
      setState(() {
        _team = team;
        _loading = false;
        _statsLoading = true;
      });

      // Today's KPI needs one call per member — load it after the list
      // is already on screen so the UI never blocks on 32 requests.
      final ids = {
        ...team.direct.map((m) => m.empId),
        ...team.tree.map((m) => m.empId),
      }.toList();
      final today = await TeamApi.fetchTeamToday(ids);
      if (!mounted) return;
      setState(() {
        _today = today;
        _statsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
        _statsLoading = false;
      });
    }
  }

  void _openProfile(TeamMember m) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EmployeeProfileScreen(empId: m.empId, fallback: m),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final members = _directOnly ? _team.direct : _team.tree;

    final q = _search.trim().toLowerCase();
    final visible = q.isEmpty
        ? members
        : members
              .where(
                (m) =>
                    m.name.toLowerCase().contains(q) ||
                    m.designation.toLowerCase().contains(q) ||
                    m.portfolio.toLowerCase().contains(q) ||
                    m.location.toLowerCase().contains(q) ||
                    m.empId.contains(q),
              )
              .toList();

    // ── Snapshot: today, across the visible group ──
    var logged = 0;
    var teamDone = 0;
    var teamPending = 0;
    for (final m in members) {
      final s = _today[m.empId];
      if (s == null) continue;
      if (s.logged) logged++;
      teamDone += s.done;
      teamPending += s.pending;
    }
    final notLogged = members.length - logged;
    final totalToday = teamDone + teamPending;
    final avgKpi = totalToday == 0 ? null : (teamDone / totalToday) * 100;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'My Team',
            style: display(
              size: 24,
              weight: FontWeight.w800,
              color: AppColors.forestDeep,
            ),
          ),
          const Text(
            'Everyone reporting under you — today at a glance.',
            style: TextStyle(fontSize: 12, color: AppColors.mute),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: _Snap(
                  label: 'Team',
                  value: '${members.length}',
                  icon: Icons.groups_2_outlined,
                  tone: AppColors.forest,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Snap(
                  label: 'On duty',
                  value: _statsLoading ? '…' : '$logged',
                  icon: Icons.task_alt,
                  tone: AppColors.forestSoft,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Snap(
                  label: 'Not logged',
                  value: _statsLoading
                      ? '…'
                      : '${notLogged < 0 ? 0 : notLogged}',
                  icon: Icons.pending_outlined,
                  tone: AppColors.slate,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Snap(
                  label: 'Avg KPI',
                  value: _statsLoading
                      ? '…'
                      : (avgKpi == null ? '—' : '${avgKpi.round()}%'),
                  icon: Icons.speed,
                  tone: AppColors.moss,
                ),
              ),
            ],
          ),

          if (!_statsLoading && totalToday > 0) ...[
            const SizedBox(height: 8),
            _KpiBar(done: teamDone, pending: teamPending),
          ],
          const SizedBox(height: 12),

          _Segmented(
            directCount: _team.direct.length,
            treeCount: _team.tree.length,
            directOnly: _directOnly,
            onChanged: (v) => setState(() => _directOnly = v),
          ),
          const SizedBox(height: 12),

          TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search, size: 18, color: AppColors.mute),
              hintText: 'Search name, role, portfolio…',
            ),
          ),
          const SizedBox(height: 14),

          if (_loading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _ErrorBox(message: _error!, onRetry: _load)
          else if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No team members found.',
                  style: TextStyle(fontSize: 13, color: AppColors.mute),
                ),
              ),
            )
          else
            for (final m in visible) ...[
              _MemberCard(
                member: m,
                stats: _today[m.empId],
                loading: _statsLoading,
                onTap: () => _openProfile(m),
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

/* ═══════════════════════════════════════════════════════════
   EMPLOYEE PROFILE — /employee_stats?emp_id=…
   ═══════════════════════════════════════════════════════════ */

class EmployeeProfileScreen extends StatefulWidget {
  final String empId;
  final TeamMember? fallback; // shows the header instantly while loading
  const EmployeeProfileScreen({super.key, required this.empId, this.fallback});

  @override
  State<EmployeeProfileScreen> createState() => _EmployeeProfileScreenState();
}

class _EmployeeProfileScreenState extends State<EmployeeProfileScreen> {
  bool _loading = true;
  String? _error;
  EmployeeStats? _stats;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await TeamApi.fetchEmployeeStats(widget.empId);
      if (!mounted) return;
      setState(() {
        _stats = s;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _assignTask() {
    // TODO: point this at your existing add-task flow, e.g.
    //   context.push('/tasks/new?assignee=${widget.empId}');
    // or call your create-task endpoint once you share it.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Hook this up to your add-task route.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _stats;
    final name = s?.name.trim().isNotEmpty == true
        ? s!.name.trim()
        : (widget.fallback?.name ?? 'Employee');
    final designation = s?.designation.trim().isNotEmpty == true
        ? s!.designation
        : (widget.fallback?.designation ?? '');
    final portfolio = s?.portfolio.trim().isNotEmpty == true
        ? s!.portfolio
        : (widget.fallback?.portfolio ?? '');

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _assignTask,
        backgroundColor: AppColors.forestDeep,
        icon: const Icon(Icons.add_task, color: Colors.white),
        label: const Text(
          'Assign Task',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            _ProfileHeader(
              name: name,
              empId: widget.empId,
              designation: designation,
              portfolio: portfolio,
              team: s?.team ?? '',
              supId: s?.supId ?? widget.fallback?.supId ?? '',
              location: widget.fallback?.location ?? '',
            ),
            const SizedBox(height: 14),

            if (_loading) ...[
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              ),
            ] else if (_error != null) ...[
              _ErrorBox(message: _error!, onRetry: _load),
            ] else if (s != null) ...[
              _SectionTitle(
                'This month',
                trailing: '${s.fromDate} → ${s.toDate}',
              ),
              const SizedBox(height: 8),

              // Today strip
              _TodayCard(day: s.today),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: _Snap(
                      label: 'Total task',
                      value: '${s.totalTask}',
                      icon: Icons.list_alt,
                      tone: AppColors.forest,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Snap(
                      label: 'Done',
                      value: '${s.done}',
                      icon: Icons.check_circle_outline,
                      tone: AppColors.forestSoft,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Snap(
                      label: 'Pending',
                      value: '${s.pending + s.processing}',
                      icon: Icons.hourglass_bottom,
                      tone: AppColors.slate,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Snap(
                      label: 'Done rate',
                      value: '${s.doneRate.round()}%',
                      icon: Icons.speed,
                      tone: AppColors.moss,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (s.totalTask > 0)
                _KpiBar(done: s.done, pending: s.pending + s.processing),
              const SizedBox(height: 14),

              // Activity
              _Panel(
                title: 'Activity',
                child: Column(
                  children: [
                    _Row2(
                      left: _Metric('Active days', '${s.activeDays}'),
                      right: _Metric('Inactive days', '${s.inactiveDays}'),
                    ),
                    const SizedBox(height: 10),
                    _Row2(
                      left: _Metric(
                        'Activity rate',
                        '${s.activityRate.toStringAsFixed(1)}%',
                      ),
                      right: _Metric(
                        'Avg task / active day',
                        s.avgTaskPerActiveDay.toStringAsFixed(2),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _Row2(
                      left: _Metric('First activity', s.firstActivity ?? '—'),
                      right: _Metric('Last activity', s.lastActivity ?? '—'),
                    ),
                    const SizedBox(height: 10),
                    _Row2(
                      left: _Metric(
                        'Busiest day',
                        s.busiestDay == null
                            ? '—'
                            : '${s.busiestDay} (${s.busiestDayCount})',
                      ),
                      right: _Metric('Top worktype', s.mostWorktype ?? '—'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              if (s.taskPerDay.isNotEmpty) ...[
                _Panel(
                  title: 'Tasks per day',
                  child: _TaskPerDayChart(data: s.taskPerDay),
                ),
                const SizedBox(height: 12),
              ],

              if (s.worktypeStats.isNotEmpty) ...[
                _Panel(
                  title: 'Work types',
                  child: Column(
                    children: [
                      for (final w in s.worktypeStats) ...[
                        _WorktypeRow(
                          label: w.worktype,
                          count: w.count,
                          ratio: w.ratio,
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              _SectionTitle('Tasks', trailing: '${s.tasks.length}'),
              const SizedBox(height: 8),
              if (s.tasks.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No tasks in this period.',
                      style: TextStyle(fontSize: 13, color: AppColors.mute),
                    ),
                  ),
                )
              else
                for (final t in s.tasks) ...[
                  _TaskCard(task: t),
                  const SizedBox(height: 8),
                ],
            ],
          ],
        ),
      ),
    );
  }
}

/* ═══════════════════════════════════════════════════════════
   SHARED WIDGETS — same visual language as before
   ═══════════════════════════════════════════════════════════ */

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String empId;
  final String designation;
  final String portfolio;
  final String team;
  final String supId;
  final String location;

  const _ProfileHeader({
    required this.name,
    required this.empId,
    required this.designation,
    required this.portfolio,
    required this.team,
    required this.supId,
    required this.location,
  });

  String get _initials {
    final parts = name
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.forestDeep, AppColors.forest],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(38),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: display(
                        size: 17,
                        weight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      designation.isEmpty ? '—' : designation,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _GlassTag(Icons.badge_outlined, '#$empId'),
              if (portfolio.isNotEmpty)
                _GlassTag(Icons.workspaces_outline, portfolio),
              if (team.isNotEmpty) _GlassTag(Icons.groups_2_outlined, team),
              if (location.isNotEmpty)
                _GlassTag(Icons.place_outlined, location),
              if (supId.isNotEmpty)
                _GlassTag(Icons.supervisor_account_outlined, 'Sup $supId'),
            ],
          ),
        ],
      ),
    );
  }
}

class _GlassTag extends StatelessWidget {
  final IconData icon;
  final String text;
  const _GlassTag(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withAlpha(31),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: Colors.white70),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _TodayCard extends StatelessWidget {
  final DayStats day;
  const _TodayCard({required this.day});

  @override
  Widget build(BuildContext context) {
    final kpi = day.kpiPct;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: (day.logged ? AppColors.forestSoft : AppColors.slate)
                  .withAlpha(31),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              day.logged ? Icons.today : Icons.event_busy,
              size: 17,
              color: day.logged ? AppColors.forestSoft : AppColors.slate,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TODAY',
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                    color: AppColors.mute,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  day.logged
                      ? '${day.done} done · ${day.pending} pending'
                      : 'No task logged today',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            kpi == null ? '—' : '${kpi.round()}%',
            style: display(
              size: 20,
              weight: FontWeight.w800,
              color: kpi == null ? AppColors.mute : AppColors.forest,
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiBar extends StatelessWidget {
  final int done;
  final int pending;
  const _KpiBar({required this.done, required this.pending});

  @override
  Widget build(BuildContext context) {
    final total = done + pending;
    final ratio = total == 0 ? 0.0 : done / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 7,
            backgroundColor: AppColors.border,
            valueColor: const AlwaysStoppedAnimation<Color>(
              AppColors.forestSoft,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '$done done · $pending pending  (of $total)',
          style: const TextStyle(fontSize: 10.5, color: AppColors.mute),
        ),
      ],
    );
  }
}

class _TaskPerDayChart extends StatelessWidget {
  final Map<String, int> data;
  const _TaskPerDayChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final keys = data.keys.toList()..sort();
    final max = data.values.fold<int>(1, (a, b) => b > a ? b : a);

    return SizedBox(
      height: 96,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final k in keys)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${data[k]}',
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.forest,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      height: 56 * (data[k]! / max),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [AppColors.forestDeep, AppColors.forestSoft],
                        ),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      k.length >= 10 ? k.substring(8) : k, // dd
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.mute,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WorktypeRow extends StatelessWidget {
  final String label;
  final int count;
  final double ratio;
  const _WorktypeRow({
    required this.label,
    required this.count,
    required this.ratio,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '$count · ${ratio.toStringAsFixed(1)}%',
            style: const TextStyle(fontSize: 10.5, color: AppColors.mute),
          ),
        ],
      ),
      const SizedBox(height: 5),
      ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          value: (ratio / 100).clamp(0.0, 1.0),
          minHeight: 5,
          backgroundColor: AppColors.border,
          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.forest),
        ),
      ),
    ],
  );
}

class _TaskCard extends StatelessWidget {
  final TaskRow task;
  const _TaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final (Color tone, String label) = task.done
        ? (AppColors.forestSoft, 'Done')
        : task.pending
        ? (AppColors.slate, 'Pending')
        : (AppColors.moss, 'Processing');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  task.details.isEmpty ? '(no details)' : task.details,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tone.withAlpha(31),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: tone,
                  ),
                ),
              ),
            ],
          ),
          if (task.remarks.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              task.remarks,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.mute,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              _Tag(task.date, tone: AppColors.forest),
              if (task.startTime.isNotEmpty)
                _Tag(task.startTime, tone: AppColors.slate),
              if (task.worktype.isNotEmpty)
                _Tag(task.worktype, tone: AppColors.moss),
              if (task.territory.isNotEmpty && task.territory != 'none')
                _Tag(task.territory, tone: AppColors.mute),
              if (task.done && task.doneDate.isNotEmpty)
                _Tag('✓ ${task.doneDate}', tone: AppColors.forestSoft),
            ],
          ),
        ],
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final TeamMember member;
  final DayStats? stats;
  final bool loading;
  final VoidCallback onTap;
  const _MemberCard({
    required this.member,
    required this.onTap,
    this.stats,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final s = stats ?? const DayStats();
    final kpi = s.kpiPct;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.forestDeep, AppColors.forest],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  member.initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            member.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: s.logged
                                ? AppColors.forestSoft
                                : AppColors.border,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      member.designation,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.mute,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        if (member.portfolio.isNotEmpty)
                          _Tag(member.portfolio, tone: AppColors.forest),
                        if (member.location.isNotEmpty)
                          _Tag(member.location, tone: AppColors.slate),
                        _Tag('#${member.empId}', tone: AppColors.mute),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: kpi == null
                          ? AppColors.border.withAlpha(90)
                          : AppColors.forest.withAlpha(31),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      loading ? '…' : (kpi == null ? '—' : '${kpi.round()}%'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: kpi == null ? AppColors.mute : AppColors.forest,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    loading
                        ? '…'
                        : s.logged
                        ? '${s.done}/${s.total} today'
                        : 'Not logged',
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: AppColors.mute,
                    ),
                  ),
                ],
              ),
              const Icon(Icons.chevron_right, size: 16, color: AppColors.mute),
            ],
          ),
        ),
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  final int directCount;
  final int treeCount;
  final bool directOnly;
  final ValueChanged<bool> onChanged;
  const _Segmented({
    required this.directCount,
    required this.treeCount,
    required this.directOnly,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget seg(String label, bool selected, VoidCallback onTap) => Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.forestDeep : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.mute,
            ),
          ),
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          seg('Direct ($directCount)', directOnly, () => onChanged(true)),
          seg('All team ($treeCount)', !directOnly, () => onChanged(false)),
        ],
      ),
    );
  }
}

class _Snap extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color tone;
  const _Snap({
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
  });

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
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 8.5,
              letterSpacing: 1,
              fontWeight: FontWeight.w600,
              color: AppColors.mute,
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final Widget child;
  const _Panel({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 9.5,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
            color: AppColors.mute,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final String? trailing;
  const _SectionTitle(this.text, {this.trailing});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        text,
        style: display(
          size: 15,
          weight: FontWeight.w800,
          color: AppColors.forestDeep,
        ),
      ),
      const Spacer(),
      if (trailing != null)
        Text(
          trailing!,
          style: const TextStyle(fontSize: 10.5, color: AppColors.mute),
        ),
    ],
  );
}

class _Row2 extends StatelessWidget {
  final Widget left;
  final Widget right;
  const _Row2({required this.left, required this.right});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: left),
      const SizedBox(width: 12),
      Expanded(child: right),
    ],
  );
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric(this.label, this.value);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 8.5,
          letterSpacing: 1,
          fontWeight: FontWeight.w600,
          color: AppColors.mute,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ],
  );
}

class _Tag extends StatelessWidget {
  final String text;
  final Color tone;
  const _Tag(this.text, {required this.tone});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: tone.withAlpha(22),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: tone),
    ),
  );
}

class _ErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBox({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      children: [
        const Icon(Icons.cloud_off, color: AppColors.mute, size: 28),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.mute),
        ),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}
