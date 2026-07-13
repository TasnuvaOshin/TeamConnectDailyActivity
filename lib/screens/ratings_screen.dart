import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api/session.dart';
import '../theme.dart';

/* ═══════════════════════════════════════════════════════════
   CONFIG
   ═══════════════════════════════════════════════════════════ */

const String _kBase = 'https://dailyactivityapi.acipanel.com';
const int _kMaxRating = 5;

const _kParams = (
  ratee: 'emp_id',
  rater: 'sup_id',
  rtaRating: 'rta_rating',
  rtaReview: 'rta_review',
  otherRating: 'other_rating',
  otherReview: 'other_review',
  month: 'month',
  year: 'year',
);

String _s(dynamic value) => (value ?? '').toString().trim();
int _i(dynamic value) => int.tryParse(_s(value)) ?? 0;
double? _d(dynamic value) => double.tryParse(_s(value));

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<dynamic> _list(dynamic value) => value is List ? value : const [];

/* ═══════════════════════════════════════════════════════════
   MODELS
   ═══════════════════════════════════════════════════════════ */

class Employee {
  final String id;
  final String empId;
  final String name;
  final String designation;
  final String portfolio;
  final String team;
  final String location;

  const Employee({
    required this.id,
    required this.empId,
    required this.name,
    required this.designation,
    required this.portfolio,
    required this.team,
    required this.location,
  });

  factory Employee.fromJson(Map<String, dynamic> json) => Employee(
        id: _s(json['id']),
        empId: _s(json['emp_id']),
        name: _s(json['emp_name']),
        designation: _s(json['emp_designation']),
        portfolio: _s(json['portfolio']),
        team: _s(json['team']),
        location: _s(json['location']),
      );

  String get initials {
    final parts =
        name.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class RatingOverview {
  final SupervisorInfo supervisor;
  final RatingFilter filter;
  final RatingSummary summary;
  final List<EmployeeOverview> employees;

  const RatingOverview({
    required this.supervisor,
    required this.filter,
    required this.summary,
    required this.employees,
  });

  factory RatingOverview.fromJson(Map<String, dynamic> json) {
    return RatingOverview(
      supervisor: SupervisorInfo.fromJson(_map(json['supervisor'])),
      filter: RatingFilter.fromJson(_map(json['filter'])),
      summary: RatingSummary.fromJson(_map(json['summary'])),
      employees: _list(json['employees'])
          .map((item) => EmployeeOverview.fromJson(_map(item)))
          .toList(),
    );
  }
}

class SupervisorInfo {
  final String empId;
  final String name;
  final String designation;

  const SupervisorInfo({
    required this.empId,
    required this.name,
    required this.designation,
  });

  factory SupervisorInfo.fromJson(Map<String, dynamic> json) => SupervisorInfo(
        empId: _s(json['emp_id']),
        name: _s(json['emp_name']),
        designation: _s(json['emp_designation']),
      );
}

class RatingFilter {
  final String month;
  final String year;
  final String fromDate;
  final String toDate;

  const RatingFilter({
    required this.month,
    required this.year,
    required this.fromDate,
    required this.toDate,
  });

  factory RatingFilter.fromJson(Map<String, dynamic> json) => RatingFilter(
        month: _s(json['month']),
        year: _s(json['year']),
        fromDate: _s(json['f_date']),
        toDate: _s(json['t_date']),
      );
}

class RatingSummary {
  final int totalEmployees;
  final int rated;
  final int notRated;
  final int ratedByMe;
  final double? teamAverage;
  final int totalTask;
  final int totalTaskDone;
  final int totalTour;
  final int agendaSubmitted;

  const RatingSummary({
    required this.totalEmployees,
    required this.rated,
    required this.notRated,
    required this.ratedByMe,
    required this.teamAverage,
    required this.totalTask,
    required this.totalTaskDone,
    required this.totalTour,
    required this.agendaSubmitted,
  });

  factory RatingSummary.fromJson(Map<String, dynamic> json) => RatingSummary(
        totalEmployees: _i(json['total_employees']),
        rated: _i(json['rated']),
        notRated: _i(json['not_rated']),
        ratedByMe: _i(json['rated_by_me']),
        teamAverage: _d(json['team_avg_rating']),
        totalTask: _i(json['total_task']),
        totalTaskDone: _i(json['total_task_done']),
        totalTour: _i(json['total_tour']),
        agendaSubmitted: _i(json['agenda_submitted']),
      );

  double get taskCompletion => totalTask == 0
      ? 0
      : (totalTaskDone / totalTask * 100).clamp(0, 100).toDouble();
}

class EmployeeOverview {
  final Employee employee;
  final EmployeeRating rating;
  final ActivitySummary task;
  final ActivitySummary tour;
  final AgendaSummary agenda;

  const EmployeeOverview({
    required this.employee,
    required this.rating,
    required this.task,
    required this.tour,
    required this.agenda,
  });

  factory EmployeeOverview.fromJson(Map<String, dynamic> json) {
    return EmployeeOverview(
      employee: Employee.fromJson(_map(json['employee'])),
      rating: EmployeeRating.fromJson(_map(json['rating'])),
      task: ActivitySummary.fromJson(_map(json['task'])),
      tour: ActivitySummary.fromJson(_map(json['tour'])),
      agenda: AgendaSummary.fromJson(_map(json['agenda'])),
    );
  }
}

class EmployeeRating {
  final int totalReview;
  final double? averageRta;
  final double? averageOther;
  final double? average;
  final double? latestRating;
  final String latestMonth;
  final String status;
  final int ratedByMeCount;

  const EmployeeRating({
    required this.totalReview,
    required this.averageRta,
    required this.averageOther,
    required this.average,
    required this.latestRating,
    required this.latestMonth,
    required this.status,
    required this.ratedByMeCount,
  });

  factory EmployeeRating.fromJson(Map<String, dynamic> json) {
    final summary = _map(json['summary']);
    final ratedByMe = _map(json['rated_by_me']);

    return EmployeeRating(
      totalReview: _i(summary['total_review']),
      averageRta: _d(summary['avg_rta_rating']),
      averageOther: _d(summary['avg_other_rating']),
      average: _d(summary['avg_rating']),
      latestRating: _d(summary['latest_rating']),
      latestMonth: _s(summary['latest_month']),
      status: _s(summary['status']),
      ratedByMeCount: _i(ratedByMe['count']),
    );
  }

  bool get isRated => status.toLowerCase() == 'rated' || totalReview > 0;
}

class ActivitySummary {
  final int total;
  final int done;
  final int pending;
  final int processing;
  final double doneRate;
  final int activeDays;
  final int tourDays;
  final String lastActivity;

  const ActivitySummary({
    required this.total,
    required this.done,
    required this.pending,
    required this.processing,
    required this.doneRate,
    required this.activeDays,
    required this.tourDays,
    required this.lastActivity,
  });

  factory ActivitySummary.fromJson(Map<String, dynamic> json) => ActivitySummary(
        total: _i(json['total']),
        done: _i(json['done']),
        pending: _i(json['pending']),
        processing: _i(json['processing']),
        doneRate: _d(json['done_rate']) ?? 0,
        activeDays: _i(json['active_days']),
        tourDays: _i(json['tour_days']),
        lastActivity: _s(json['last_activity']),
      );
}

class AgendaSummary {
  final bool submitted;
  final int total;
  final int linkedTasks;
  final double linkRate;

  const AgendaSummary({
    required this.submitted,
    required this.total,
    required this.linkedTasks,
    required this.linkRate,
  });

  factory AgendaSummary.fromJson(Map<String, dynamic> json) => AgendaSummary(
        submitted: json['submitted'] == true ||
            _s(json['submitted']).toLowerCase() == 'true' ||
            _s(json['submitted']) == '1',
        total: _i(json['total']),
        linkedTasks: _i(json['linked_tasks']),
        linkRate: _d(json['link_rate']) ?? 0,
      );
}

/* ═══════════════════════════════════════════════════════════
   API
   ═══════════════════════════════════════════════════════════ */

class RatingApi {
  static Future<List<Employee>> fetchUnderMySupervision(String myEmpId) async {
    final uri = Uri.parse('$_kBase/team').replace(
      queryParameters: {'id': myEmpId},
    );

    final response =
        await http.get(uri).timeout(const Duration(seconds: 25));

    if (response.statusCode != 200) {
      throw Exception('Server error (${response.statusCode})');
    }

    final body = _map(jsonDecode(response.body));
    if (_s(body['response']) != '200') {
      throw Exception(_s(body['message']).isEmpty
          ? 'Could not load team'
          : _s(body['message']));
    }

    final employees = _list(body['under_my_supervison'])
        .map((item) => Employee.fromJson(_map(item)))
        .where((employee) => employee.empId.isNotEmpty)
        .toList()
      ..sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

    return employees;
  }

  static Future<RatingOverview> fetchOverview({
    required String empId,
    required String month,
    required String year,
  }) async {
    final uri = Uri.parse('$_kBase/ratings').replace(
      queryParameters: {
        'emp_id': empId,
        'month': month,
        'year': year,
      },
    );

    final response =
        await http.get(uri).timeout(const Duration(seconds: 25));

    if (response.statusCode != 200) {
      throw Exception('Server error (${response.statusCode})');
    }

    final body = _map(jsonDecode(response.body));
    if (_s(body['response']) != '200') {
      final message = _s(body['message'] ?? body['error']);
      throw Exception(message.isEmpty ? 'Could not load overview' : message);
    }

    return RatingOverview.fromJson(body);
  }

  static Future<void> addRate({
    required String rateeEmpId,
    required String myEmpId,
    required double rtaRating,
    required String rtaReview,
    required double otherRating,
    required String otherReview,
  }) async {
    final now = DateTime.now();

    final response = await http
        .post(
          Uri.parse('$_kBase/add_rate'),
          body: {
            _kParams.ratee: rateeEmpId,
            _kParams.rater: myEmpId,
            _kParams.rtaRating: rtaRating.toString(),
            _kParams.rtaReview: rtaReview,
            _kParams.otherRating: otherRating.toString(),
            _kParams.otherReview: otherReview,
            _kParams.month: now.month.toString().padLeft(2, '0'),
            _kParams.year: now.year.toString(),
          },
        )
        .timeout(const Duration(seconds: 25));

    if (response.statusCode != 200) {
      throw Exception('Server error (${response.statusCode})');
    }

    final body = _map(jsonDecode(response.body));
    if (_s(body['response']) != '200') {
      final message = _s(body['message'] ?? body['error']);
      throw Exception(message.isEmpty ? 'Could not save rating' : message);
    }
  }
}

/* ═══════════════════════════════════════════════════════════
   SCREEN
   ═══════════════════════════════════════════════════════════ */

class RatingsScreen extends StatefulWidget {
  final String? empId;

  const RatingsScreen({super.key, this.empId});

  @override
  State<RatingsScreen> createState() => _RatingsScreenState();
}

class _RatingsScreenState extends State<RatingsScreen> {
  String? _myEmpId;

  bool _teamLoading = true;
  bool _overviewLoading = true;

  String? _teamError;
  String? _overviewError;

  List<Employee> _employees = const [];
  RatingOverview? _overview;

  late String _selectedMonth;
  late String _selectedYear;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month.toString().padLeft(2, '0');
    _selectedYear = now.year.toString();
    _loadInitialData();
  }

  Future<String> _resolveEmpId() async {
    var empId = _myEmpId ?? widget.empId;

    if (empId == null || empId.trim().isEmpty) {
      final session = await SessionStore().load();
      empId = session?.empId;
    }

    if (empId == null || empId.trim().isEmpty) {
      throw Exception('No signed-in user found');
    }

    _myEmpId = empId.trim();
    return _myEmpId!;
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _teamLoading = true;
      _overviewLoading = true;
      _teamError = null;
      _overviewError = null;
    });

    try {
      final empId = await _resolveEmpId();

      final results = await Future.wait<dynamic>([
        RatingApi.fetchUnderMySupervision(empId),
        RatingApi.fetchOverview(
          empId: empId,
          month: _selectedMonth,
          year: _selectedYear,
        ),
      ]);

      if (!mounted) return;

      setState(() {
        _employees = results[0] as List<Employee>;
        _overview = results[1] as RatingOverview;
        _teamLoading = false;
        _overviewLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      setState(() {
        _teamError = message;
        _overviewError = message;
        _teamLoading = false;
        _overviewLoading = false;
      });
    }
  }

  Future<void> _loadTeam() async {
    setState(() {
      _teamLoading = true;
      _teamError = null;
    });

    try {
      final empId = await _resolveEmpId();
      final employees = await RatingApi.fetchUnderMySupervision(empId);

      if (!mounted) return;
      setState(() {
        _employees = employees;
        _teamLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _teamError = error.toString().replaceFirst('Exception: ', '');
        _teamLoading = false;
      });
    }
  }

  Future<void> _loadOverview() async {
    setState(() {
      _overviewLoading = true;
      _overviewError = null;
    });

    try {
      final empId = await _resolveEmpId();
      final overview = await RatingApi.fetchOverview(
        empId: empId,
        month: _selectedMonth,
        year: _selectedYear,
      );

      if (!mounted) return;
      setState(() {
        _overview = overview;
        _overviewLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _overviewError = error.toString().replaceFirst('Exception: ', '');
        _overviewLoading = false;
      });
    }
  }

  Future<void> _openRateDialog(Employee employee) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RateDialog(
        employee: employee,
        myEmpId: _myEmpId!,
      ),
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rating submitted for ${employee.name.trim()}'),
          backgroundColor: AppColors.forest,
        ),
      );
      await _loadOverview();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Team Ratings',
                  style: display(
                    size: 24,
                    weight: FontWeight.w800,
                    color: AppColors.forestDeep,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Review performance and rate employees under your supervision.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.mute,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TabBar(
                    indicator: BoxDecoration(
                      color: AppColors.forestDeep,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: Colors.white,
                    unselectedLabelColor: AppColors.mute,
                    labelStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.star_rounded, size: 18),
                        text: 'Rate My Team',
                      ),
                      Tab(
                        icon: Icon(Icons.dashboard_rounded, size: 18),
                        text: 'Rating Overview',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildRateTeamTab(),
                _buildOverviewTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRateTeamTab() {
    return RefreshIndicator(
      onRefresh: _loadTeam,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_teamLoading)
            const _LoadingBox(message: 'Loading employees...')
          else if (_teamError != null)
            _ErrorBox(message: _teamError!, onRetry: _loadTeam)
          else if (_employees.isEmpty)
            const _EmptyBox(
              icon: Icons.groups_outlined,
              title: 'No employees found',
              message: 'No employees are currently under your supervision.',
            )
          else
            for (final employee in _employees) ...[
              _EmployeeCard(
                employee: employee,
                onRate: () => _openRateDialog(employee),
              ),
              const SizedBox(height: 10),
            ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _loadOverview,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _OverviewFilter(
            selectedMonth: _selectedMonth,
            selectedYear: _selectedYear,
            loading: _overviewLoading,
            onMonthChanged: (value) {
              if (value == null) return;
              setState(() => _selectedMonth = value);
              _loadOverview();
            },
            onYearChanged: (value) {
              if (value == null) return;
              setState(() => _selectedYear = value);
              _loadOverview();
            },
          ),
          const SizedBox(height: 14),
          if (_overviewLoading)
            const _LoadingBox(message: 'Loading rating overview...')
          else if (_overviewError != null)
            _ErrorBox(message: _overviewError!, onRetry: _loadOverview)
          else if (_overview == null)
            const _EmptyBox(
              icon: Icons.analytics_outlined,
              title: 'No overview available',
              message: 'Rating overview data could not be found.',
            )
          else ...[
            _SupervisorCard(
              supervisor: _overview!.supervisor,
              filter: _overview!.filter,
            ),
            const SizedBox(height: 14),
            _SummaryGrid(summary: _overview!.summary),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Employee Performance',
                    style: display(
                      size: 17,
                      weight: FontWeight.w800,
                      color: AppColors.forestDeep,
                    ),
                  ),
                ),
                Text(
                  '${_overview!.employees.length} employee${_overview!.employees.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.mute,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_overview!.employees.isEmpty)
              const _EmptyBox(
                icon: Icons.person_search_outlined,
                title: 'No employee data',
                message: 'No employee performance was found for this period.',
              )
            else
              for (final item in _overview!.employees) ...[
                _OverviewEmployeeCard(
                  item: item,
                  onRate: () => _openRateDialog(item.employee),
                ),
                const SizedBox(height: 12),
              ],
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/* ═══════════════════════════════════════════════════════════
   OVERVIEW WIDGETS
   ═══════════════════════════════════════════════════════════ */

class _OverviewFilter extends StatelessWidget {
  final String selectedMonth;
  final String selectedYear;
  final bool loading;
  final ValueChanged<String?> onMonthChanged;
  final ValueChanged<String?> onYearChanged;

  const _OverviewFilter({
    required this.selectedMonth,
    required this.selectedYear,
    required this.loading,
    required this.onMonthChanged,
    required this.onYearChanged,
  });

  static const _months = <String, String>{
    '01': 'January',
    '02': 'February',
    '03': 'March',
    '04': 'April',
    '05': 'May',
    '06': 'June',
    '07': 'July',
    '08': 'August',
    '09': 'September',
    '10': 'October',
    '11': 'November',
    '12': 'December',
  };

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    final years = List.generate(
      7,
      (index) => (currentYear - 5 + index).toString(),
    );

    if (!years.contains(selectedYear)) {
      years.add(selectedYear);
      years.sort();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_month_rounded,
            color: AppColors.forest,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              value: selectedMonth,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Month',
                isDense: true,
              ),
              items: _months.entries
                  .map(
                    (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                  .toList(),
              onChanged: loading ? null : onMonthChanged,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: selectedYear,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Year',
                isDense: true,
              ),
              items: years
                  .map(
                    (year) => DropdownMenuItem(
                      value: year,
                      child: Text(year),
                    ),
                  )
                  .toList(),
              onChanged: loading ? null : onYearChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _SupervisorCard extends StatelessWidget {
  final SupervisorInfo supervisor;
  final RatingFilter filter;

  const _SupervisorCard({
    required this.supervisor,
    required this.filter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.forestDeep, AppColors.forest],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(35),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.supervisor_account_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  supervisor.name.isEmpty ? 'Supervisor' : supervisor.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: display(
                    size: 16,
                    weight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  supervisor.designation,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  children: [
                    _LightTag('#${supervisor.empId}'),
                    _LightTag('${filter.month}/${filter.year}'),
                    if (filter.fromDate.isNotEmpty && filter.toDate.isNotEmpty)
                      _LightTag('${filter.fromDate} to ${filter.toDate}'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final RatingSummary summary;

  const _SummaryGrid({required this.summary});

  @override
  Widget build(BuildContext context) {
    final items = [
      _SummaryItem(
        title: 'Employees',
        value: '${summary.totalEmployees}',
        subtitle: '${summary.rated} rated',
        icon: Icons.groups_rounded,
      ),
      _SummaryItem(
        title: 'Not Rated',
        value: '${summary.notRated}',
        subtitle: '${summary.ratedByMe} rated by me',
        icon: Icons.star_border_rounded,
      ),
      _SummaryItem(
        title: 'Team Average',
        value: summary.teamAverage == null
            ? '—'
            : summary.teamAverage!.toStringAsFixed(1),
        subtitle: 'out of $_kMaxRating',
        icon: Icons.insights_rounded,
      ),
      _SummaryItem(
        title: 'Tasks',
        value: '${summary.totalTaskDone}/${summary.totalTask}',
        subtitle: '${summary.taskCompletion.toStringAsFixed(0)}% completed',
        icon: Icons.task_alt_rounded,
      ),
      _SummaryItem(
        title: 'Tours',
        value: '${summary.totalTour}',
        subtitle: 'for selected month',
        icon: Icons.route_rounded,
      ),
      _SummaryItem(
        title: 'Agendas',
        value: '${summary.agendaSubmitted}',
        subtitle: 'submitted',
        icon: Icons.event_note_rounded,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 700 ? 3 : 2;
        final width =
            (constraints.maxWidth - ((columns - 1) * 10)) / columns;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: item,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  const _SummaryItem({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.all(13),
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
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.forest.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppColors.forest),
              ),
              const Spacer(),
              Text(
                value,
                style: display(
                  size: 20,
                  weight: FontWeight.w800,
                  color: AppColors.forestDeep,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.mute,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewEmployeeCard extends StatelessWidget {
  final EmployeeOverview item;
  final VoidCallback onRate;

  const _OverviewEmployeeCard({
    required this.item,
    required this.onRate,
  });

  @override
  Widget build(BuildContext context) {
    final employee = item.employee;
    final rating = item.rating;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.forestDeep, AppColors.forest],
                    ),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    employee.initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        employee.designation,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.mute,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: [
                          if (employee.portfolio.isNotEmpty)
                            _Tag(employee.portfolio, tone: AppColors.forest),
                          if (employee.team.isNotEmpty)
                            _Tag(employee.team, tone: AppColors.slate),
                          if (employee.location.isNotEmpty)
                            _Tag(employee.location, tone: AppColors.mute),
                          _Tag('#${employee.empId}', tone: AppColors.mute),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _RatingBadge(rating: rating),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 420;
                final metrics = [
                  _MetricBox(
                    icon: Icons.task_alt_rounded,
                    title: 'Tasks',
                    value: '${item.task.done}/${item.task.total}',
                    subtitle: '${item.task.doneRate.toStringAsFixed(0)}% done',
                  ),
                  _MetricBox(
                    icon: Icons.pending_actions_rounded,
                    title: 'Pending',
                    value: '${item.task.pending}',
                    subtitle: '${item.task.processing} processing',
                  ),
                  _MetricBox(
                    icon: Icons.calendar_today_rounded,
                    title: 'Active',
                    value: '${item.task.activeDays} days',
                    subtitle: item.task.lastActivity.isEmpty
                        ? 'No activity'
                        : item.task.lastActivity,
                  ),
                  _MetricBox(
                    icon: Icons.route_rounded,
                    title: 'Tours',
                    value: '${item.tour.total}',
                    subtitle: '${item.tour.tourDays} tour days',
                  ),
                ];

                if (compact) {
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: metrics
                        .map(
                          (metric) => SizedBox(
                            width: (constraints.maxWidth - 8) / 2,
                            child: metric,
                          ),
                        )
                        .toList(),
                  );
                }

                return Row(
                  children: [
                    for (var index = 0; index < metrics.length; index++) ...[
                      Expanded(child: metrics[index]),
                      if (index != metrics.length - 1)
                        const SizedBox(width: 8),
                    ],
                  ],
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        item.agenda.submitted
                            ? Icons.check_circle_rounded
                            : Icons.cancel_outlined,
                        size: 16,
                        color: item.agenda.submitted
                            ? AppColors.forest
                            : AppColors.mute,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          item.agenda.submitted
                              ? 'Agenda submitted'
                              : 'Agenda not submitted',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: item.agenda.submitted
                                ? AppColors.forest
                                : AppColors.mute,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: AppColors.forestDeep,
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: onRate,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            rating.isRated ? 'Rate Again' : 'Rate Now',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  final EmployeeRating rating;

  const _RatingBadge({required this.rating});

  @override
  Widget build(BuildContext context) {
    final value = rating.average;

    return Container(
      constraints: const BoxConstraints(minWidth: 58),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: rating.isRated
            ? AppColors.amber.withAlpha(24)
            : AppColors.mute.withAlpha(14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: rating.isRated
              ? AppColors.amber.withAlpha(80)
              : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          Icon(
            rating.isRated ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 18,
            color: rating.isRated ? AppColors.amber : AppColors.mute,
          ),
          const SizedBox(height: 2),
          Text(
            value == null ? '—' : value.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color:
                  rating.isRated ? AppColors.forestDeep : AppColors.mute,
            ),
          ),
          Text(
            rating.isRated ? '${rating.totalReview} review' : 'Not rated',
            style: const TextStyle(
              fontSize: 8.5,
              color: AppColors.mute,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;

  const _MetricBox({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.forest),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            title,
            style: const TextStyle(
              fontSize: 9,
              color: AppColors.mute,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 8.5,
              color: AppColors.mute,
            ),
          ),
        ],
      ),
    );
  }
}

/* ═══════════════════════════════════════════════════════════
   RATE TEAM WIDGETS
   ═══════════════════════════════════════════════════════════ */

class _EmployeeCard extends StatelessWidget {
  final Employee employee;
  final VoidCallback onRate;

  const _EmployeeCard({
    required this.employee,
    required this.onRate,
  });

  @override
  Widget build(BuildContext context) {
    final employee = this.employee;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.forestDeep, AppColors.forest],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              employee.initials,
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
                Text(
                  employee.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  employee.designation,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.mute,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    if (employee.portfolio.isNotEmpty)
                      _Tag(employee.portfolio, tone: AppColors.forest),
                    if (employee.team.isNotEmpty)
                      _Tag(employee.team, tone: AppColors.slate),
                    if (employee.location.isNotEmpty)
                      _Tag(employee.location, tone: AppColors.mute),
                    _Tag('#${employee.empId}', tone: AppColors.mute),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: AppColors.forestDeep,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onRate,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded, size: 14, color: Colors.white),
                    SizedBox(width: 5),
                    Text(
                      'Rate Now',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ═══════════════════════════════════════════════════════════
   RATE DIALOG
   ═══════════════════════════════════════════════════════════ */

class _RateDialog extends StatefulWidget {
  final Employee employee;
  final String myEmpId;

  const _RateDialog({
    required this.employee,
    required this.myEmpId,
  });

  @override
  State<_RateDialog> createState() => _RateDialogState();
}

class _RateDialogState extends State<_RateDialog> {
  double _rate = 0;
  double _otherRate = 0;

  final _description = TextEditingController();
  final _details = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _description.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rate == 0 && _otherRate == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Give at least one rating'),
          backgroundColor: AppColors.destructive,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await RatingApi.addRate(
        rateeEmpId: widget.employee.empId,
        myEmpId: widget.myEmpId,
        rtaRating: _rate,
        rtaReview: _description.text.trim(),
        otherRating: _otherRate,
        otherReview: _details.text.trim(),
      );

      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Exception: ', ''),
          ),
          backgroundColor: AppColors.destructive,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final employee = widget.employee;

    return Dialog(
      backgroundColor: AppColors.bg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.forestDeep, AppColors.forest],
                  ),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(38),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        employee.initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            employee.name,
                            overflow: TextOverflow.ellipsis,
                            style: display(
                              size: 15,
                              weight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${employee.designation} · #${employee.empId}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white70,
                      ),
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _StarField(
                      label: 'RTA Rating',
                      value: _rate,
                      onChanged: (value) => setState(() => _rate = value),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _description,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'RTA review or description',
                      ),
                    ),
                    const SizedBox(height: 18),
                    _StarField(
                      label: 'Other Task Rating',
                      value: _otherRate,
                      onChanged: (value) =>
                          setState(() => _otherRate = value),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _details,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Other task review or details',
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _saving ? null : _submit,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Submit Rating'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StarField extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const _StarField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
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
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                value == 0
                    ? '—'
                    : '${value.toStringAsFixed(0)}/$_kMaxRating',
                style: display(
                  size: 15,
                  weight: FontWeight.w800,
                  color: value == 0 ? AppColors.mute : AppColors.forest,
                ),
              ),
            ],
          ),
          Row(
            children: [
              for (var index = 1; index <= _kMaxRating; index++)
                Expanded(
                  child: IconButton(
                    onPressed: () => onChanged(index.toDouble()),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minHeight: 42),
                    icon: Icon(
                      index <= value
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 30,
                      color: index <= value
                          ? AppColors.amber
                          : AppColors.border,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/* ═══════════════════════════════════════════════════════════
   SHARED WIDGETS
   ═══════════════════════════════════════════════════════════ */

class _Tag extends StatelessWidget {
  final String text;
  final Color tone;

  const _Tag(this.text, {required this.tone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: tone.withAlpha(22),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          color: tone,
        ),
      ),
    );
  }
}

class _LightTag extends StatelessWidget {
  final String text;

  const _LightTag(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(28),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _LoadingBox extends StatelessWidget {
  final String message;

  const _LoadingBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.mute,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyBox({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.mute, size: 32),
          const SizedBox(height: 9),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.mute,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBox({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off,
            color: AppColors.mute,
            size: 28,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.mute,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
