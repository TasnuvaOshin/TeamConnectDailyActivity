import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../api/session.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';

const String _baseUrl = 'https://dailyactivityapi.acipanel.com';
const int _maxRating = 5;

String _text(dynamic value) => (value ?? '').toString().trim();
int _toInt(dynamic value) => int.tryParse(_text(value)) ?? 0;
double? _toDouble(dynamic value) => double.tryParse(_text(value));

Map<String, dynamic> _asMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<dynamic> _asList(dynamic value) => value is List ? value : const [];

/* ═══════════════════════════════════════════════════════════
   MODELS
   ═══════════════════════════════════════════════════════════ */

class PerformanceResponse {
  final Supervisor supervisor;
  final PerformanceFilter filter;
  final PerformanceSummary summary;
  final List<EmployeePerformance> employees;

  const PerformanceResponse({
    required this.supervisor,
    required this.filter,
    required this.summary,
    required this.employees,
  });

  factory PerformanceResponse.fromJson(Map<String, dynamic> json) {
    return PerformanceResponse(
      supervisor: Supervisor.fromJson(_asMap(json['supervisor'])),
      filter: PerformanceFilter.fromJson(_asMap(json['filter'])),
      summary: PerformanceSummary.fromJson(_asMap(json['summary'])),
      employees: _asList(json['employees'])
          .map((item) => EmployeePerformance.fromJson(_asMap(item)))
          .toList(),
    );
  }
}

class Supervisor {
  final String empId;
  final String name;
  final String designation;

  const Supervisor({
    required this.empId,
    required this.name,
    required this.designation,
  });

  factory Supervisor.fromJson(Map<String, dynamic> json) => Supervisor(
        empId: _text(json['emp_id']),
        name: _text(json['emp_name']),
        designation: _text(json['emp_designation']),
      );
}

class PerformanceFilter {
  final String month;
  final String year;
  final String fromDate;
  final String toDate;

  const PerformanceFilter({
    required this.month,
    required this.year,
    required this.fromDate,
    required this.toDate,
  });

  factory PerformanceFilter.fromJson(Map<String, dynamic> json) =>
      PerformanceFilter(
        month: _text(json['month']),
        year: _text(json['year']),
        fromDate: _text(json['f_date']),
        toDate: _text(json['t_date']),
      );
}

class PerformanceSummary {
  final int totalEmployees;
  final int rated;
  final int notRated;
  final int ratedByMe;
  final double? teamAverage;
  final int totalTask;
  final int totalTaskDone;
  final int totalTour;
  final int agendaSubmitted;

  const PerformanceSummary({
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

  factory PerformanceSummary.fromJson(Map<String, dynamic> json) =>
      PerformanceSummary(
        totalEmployees: _toInt(json['total_employees']),
        rated: _toInt(json['rated']),
        notRated: _toInt(json['not_rated']),
        ratedByMe: _toInt(json['rated_by_me']),
        teamAverage: _toDouble(json['team_avg_rating']),
        totalTask: _toInt(json['total_task']),
        totalTaskDone: _toInt(json['total_task_done']),
        totalTour: _toInt(json['total_tour']),
        agendaSubmitted: _toInt(json['agenda_submitted']),
      );

  double get taskRate =>
      totalTask == 0 ? 0 : (totalTaskDone / totalTask * 100).clamp(0, 100);
}

class EmployeePerformance {
  final EmployeeInfo employee;
  final RatingData rating;
  final WorkData task;
  final WorkData tour;
  final AgendaData agenda;

  const EmployeePerformance({
    required this.employee,
    required this.rating,
    required this.task,
    required this.tour,
    required this.agenda,
  });

  factory EmployeePerformance.fromJson(Map<String, dynamic> json) {
    return EmployeePerformance(
      employee: EmployeeInfo.fromJson(_asMap(json['employee'])),
      rating: RatingData.fromJson(_asMap(json['rating'])),
      task: WorkData.fromJson(_asMap(json['task'])),
      tour: WorkData.fromJson(_asMap(json['tour'])),
      agenda: AgendaData.fromJson(_asMap(json['agenda'])),
    );
  }
}

class EmployeeInfo {
  final String empId;
  final String name;
  final String designation;
  final String portfolio;
  final String team;
  final String location;

  const EmployeeInfo({
    required this.empId,
    required this.name,
    required this.designation,
    required this.portfolio,
    required this.team,
    required this.location,
  });

  factory EmployeeInfo.fromJson(Map<String, dynamic> json) => EmployeeInfo(
        empId: _text(json['emp_id']),
        name: _text(json['emp_name']),
        designation: _text(json['emp_designation']),
        portfolio: _text(json['portfolio']),
        team: _text(json['team']),
        location: _text(json['location']),
      );

  String get initials {
    final parts =
        name.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();

    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();

    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}

class RatingData {
  final RatingSummaryData summary;
  final List<MonthRating> monthwise;
  final int ratedByMeCount;
  final List<RatingReview> ratedByMeReviews;

  const RatingData({
    required this.summary,
    required this.monthwise,
    required this.ratedByMeCount,
    required this.ratedByMeReviews,
  });

  factory RatingData.fromJson(Map<String, dynamic> json) {
    final ratedByMe = _asMap(json['rated_by_me']);

    return RatingData(
      summary: RatingSummaryData.fromJson(_asMap(json['summary'])),
      monthwise: _asList(json['monthwise'])
          .map((item) => MonthRating.fromJson(_asMap(item)))
          .toList(),
      ratedByMeCount: _toInt(ratedByMe['count']),
      ratedByMeReviews: _asList(ratedByMe['reviews'])
          .map((item) => RatingReview.fromJson(_asMap(item)))
          .toList(),
    );
  }
}

class RatingSummaryData {
  final int totalReview;
  final double? averageRta;
  final double? averageOther;
  final double? average;
  final double? highest;
  final double? lowest;
  final double? latest;
  final String latestMonth;
  final String status;

  const RatingSummaryData({
    required this.totalReview,
    required this.averageRta,
    required this.averageOther,
    required this.average,
    required this.highest,
    required this.lowest,
    required this.latest,
    required this.latestMonth,
    required this.status,
  });

  factory RatingSummaryData.fromJson(Map<String, dynamic> json) =>
      RatingSummaryData(
        totalReview: _toInt(json['total_review']),
        averageRta: _toDouble(json['avg_rta_rating']),
        averageOther: _toDouble(json['avg_other_rating']),
        average: _toDouble(json['avg_rating']),
        highest: _toDouble(json['highest_rating']),
        lowest: _toDouble(json['lowest_rating']),
        latest: _toDouble(json['latest_rating']),
        latestMonth: _text(json['latest_month']),
        status: _text(json['status']),
      );

  bool get isRated =>
      status.toLowerCase() == 'rated' || totalReview > 0 || average != null;
}

class MonthRating {
  final String label;
  final RatingSummaryData summary;
  final List<RatingReview> reviews;

  const MonthRating({
    required this.label,
    required this.summary,
    required this.reviews,
  });

  factory MonthRating.fromJson(Map<String, dynamic> json) => MonthRating(
        label: _text(json['label']),
        summary: RatingSummaryData.fromJson(_asMap(json['summary'])),
        reviews: _asList(json['reviews'])
            .map((item) => RatingReview.fromJson(_asMap(item)))
            .toList(),
      );
}

class RatingReview {
  final String date;
  final String time;
  final double? rtaRating;
  final String rtaReview;
  final double? otherRating;
  final String otherReview;
  final double? average;
  final RatedBy ratedBy;

  const RatingReview({
    required this.date,
    required this.time,
    required this.rtaRating,
    required this.rtaReview,
    required this.otherRating,
    required this.otherReview,
    required this.average,
    required this.ratedBy,
  });

  factory RatingReview.fromJson(Map<String, dynamic> json) => RatingReview(
        date: _text(json['date']),
        time: _text(json['time']),
        rtaRating: _toDouble(json['rta_rating']),
        rtaReview: _text(json['rta_review']),
        otherRating: _toDouble(json['other_rating']),
        otherReview: _text(json['other_review']),
        average: _toDouble(json['avg_rating']),
        ratedBy: RatedBy.fromJson(_asMap(json['rated_by'])),
      );
}

class RatedBy {
  final String empId;
  final String name;
  final String designation;

  const RatedBy({
    required this.empId,
    required this.name,
    required this.designation,
  });

  factory RatedBy.fromJson(Map<String, dynamic> json) => RatedBy(
        empId: _text(json['emp_id']),
        name: _text(json['emp_name']),
        designation: _text(json['emp_designation']),
      );
}

class WorkData {
  final int total;
  final int done;
  final int pending;
  final int processing;
  final double doneRate;
  final int activeDays;
  final int tourDays;
  final String lastActivity;

  const WorkData({
    required this.total,
    required this.done,
    required this.pending,
    required this.processing,
    required this.doneRate,
    required this.activeDays,
    required this.tourDays,
    required this.lastActivity,
  });

  factory WorkData.fromJson(Map<String, dynamic> json) => WorkData(
        total: _toInt(json['total']),
        done: _toInt(json['done']),
        pending: _toInt(json['pending']),
        processing: _toInt(json['processing']),
        doneRate: _toDouble(json['done_rate']) ?? 0,
        activeDays: _toInt(json['active_days']),
        tourDays: _toInt(json['tour_days']),
        lastActivity: _text(json['last_activity']),
      );
}

class AgendaData {
  final bool submitted;
  final int total;
  final int linkedTasks;
  final double linkRate;

  const AgendaData({
    required this.submitted,
    required this.total,
    required this.linkedTasks,
    required this.linkRate,
  });

  factory AgendaData.fromJson(Map<String, dynamic> json) => AgendaData(
        submitted: json['submitted'] == true ||
            _text(json['submitted']).toLowerCase() == 'true' ||
            _text(json['submitted']) == '1',
        total: _toInt(json['total']),
        linkedTasks: _toInt(json['linked_tasks']),
        linkRate: _toDouble(json['link_rate']) ?? 0,
      );
}

/* ═══════════════════════════════════════════════════════════
   API
   ═══════════════════════════════════════════════════════════ */

class PerformanceApi {
  static Future<PerformanceResponse> fetchPerformance({
    required String empId,
    required String month,
    required String year,
  }) async {
    final uri = Uri.parse('$_baseUrl/ratings').replace(
      queryParameters: {
        'emp_id': empId,
        'month': month,
        'year': year,
      },
    );

    final response =
        await http.get(uri).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('Server error (${response.statusCode})');
    }

    final body = _asMap(jsonDecode(response.body));

    if (_text(body['response']) != '200') {
      final message = _text(body['message'] ?? body['error']);
      throw Exception(
        message.isEmpty ? 'Unable to load employee performance' : message,
      );
    }

    return PerformanceResponse.fromJson(body);
  }

  static Future<void> submitRating({
    required String employeeId,
    required String supervisorId,
    required double rtaRating,
    required String rtaReview,
    required double otherRating,
    required String otherReview,
    required String month,
    required String year,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/add_rate'),
          body: {
            'emp_id': employeeId,
            'sup_id': supervisorId,
            'rta_rating': rtaRating.toString(),
            'rta_review': rtaReview,
            'other_rating': otherRating.toString(),
            'other_review': otherReview,
            'month': month,
            'year': year,
          },
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('Server error (${response.statusCode})');
    }

    final body = _asMap(jsonDecode(response.body));

    if (_text(body['response']) != '200') {
      final message = _text(body['message'] ?? body['error']);
      throw Exception(message.isEmpty ? 'Unable to save rating' : message);
    }
  }
}

/* ═══════════════════════════════════════════════════════════
   ADMIN SCREEN
   ═══════════════════════════════════════════════════════════ */

class AdminScreen extends ConsumerStatefulWidget {
  final String? empId;

  const AdminScreen({super.key, this.empId});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  final TextEditingController _searchController = TextEditingController();

  PerformanceResponse? _data;
  String? _supervisorEmpId;
  String? _error;

  bool _loading = true;
  String _selectedStatus = 'all';

  late String _selectedMonth;
  late String _selectedYear;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    _selectedMonth = now.month.toString().padLeft(2, '0');
    _selectedYear = now.year.toString();

    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<String> _resolveEmpId() async {
    var empId = widget.empId ?? _supervisorEmpId;

    if (empId == null || empId.trim().isEmpty) {
      final session = await SessionStore().load();
      empId = session?.empId;
    }

    if (empId == null || empId.trim().isEmpty) {
      throw Exception('No signed-in employee ID found');
    }

    _supervisorEmpId = empId.trim();
    return _supervisorEmpId!;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final empId = await _resolveEmpId();

      final response = await PerformanceApi.fetchPerformance(
        empId: empId,
        month: _selectedMonth,
        year: _selectedYear,
      );

      if (!mounted) return;

      setState(() {
        _data = response;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  List<EmployeePerformance> get _filteredEmployees {
    final source = _data?.employees ?? const <EmployeePerformance>[];
    final query = _searchController.text.trim().toLowerCase();

    return source.where((item) {
      final employee = item.employee;
      final rating = item.rating.summary;

      final matchesSearch = query.isEmpty ||
          employee.name.toLowerCase().contains(query) ||
          employee.empId.toLowerCase().contains(query) ||
          employee.designation.toLowerCase().contains(query) ||
          employee.portfolio.toLowerCase().contains(query) ||
          employee.team.toLowerCase().contains(query) ||
          employee.location.toLowerCase().contains(query);

      final matchesStatus = switch (_selectedStatus) {
        'rated' => rating.isRated,
        'not_rated' => !rating.isRated,
        _ => true,
      };

      return matchesSearch && matchesStatus;
    }).toList()
      ..sort((a, b) {
        final aRating = a.rating.summary.average ?? -1;
        final bRating = b.rating.summary.average ?? -1;

        if (aRating != bRating) return bRating.compareTo(aRating);
        return a.employee.name.compareTo(b.employee.name);
      });
  }

  Future<void> _openRateDialog(EmployeePerformance employee) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RatingDialog(
        employee: employee.employee,
        supervisorId: _supervisorEmpId!,
        month: _selectedMonth,
        year: _selectedYear,
      ),
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rating submitted for ${employee.employee.name}'),
          backgroundColor: AppColors.forest,
        ),
      );

      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final roles = ref.watch(myRolesProvider).valueOrNull ?? const [];

    if (!roles.contains('admin')) {
      return const Center(
        child: Text(
          'Admin access only.',
          style: TextStyle(color: AppColors.mute),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildFilters(),
          const SizedBox(height: 16),
          if (_loading)
            const _LoadingState()
          else if (_error != null)
            _ErrorState(message: _error!, onRetry: _load)
          else if (_data == null)
            const _EmptyState(
              title: 'No performance data',
              message: 'No employee performance information is available.',
            )
          else ...[
            _SupervisorBanner(
              supervisor: _data!.supervisor,
              filter: _data!.filter,
            ),
            const SizedBox(height: 16),
            _SummarySection(summary: _data!.summary),
            const SizedBox(height: 18),
            _buildEmployeeHeader(),
            const SizedBox(height: 10),
            if (_filteredEmployees.isEmpty)
              const _EmptyState(
                title: 'No matching employees',
                message: 'Try changing the search or rating status filter.',
              )
            else
              for (final employee in _filteredEmployees) ...[
                _EmployeePerformanceCard(
                  item: employee,
                  onRate: () => _openRateDialog(employee),
                ),
                const SizedBox(height: 12),
              ],
          ],
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.forestDeep,
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.analytics_rounded,
            color: Colors.white,
            size: 23,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Employee Performance',
                style: display(
                  size: 24,
                  weight: FontWeight.w800,
                  color: AppColors.forestDeep,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Review activity, ratings, tours, agendas and employee feedback.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.mute,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    final currentYear = DateTime.now().year;
    final years = List.generate(
      8,
      (index) => (currentYear - 6 + index).toString(),
    );

    if (!years.contains(_selectedYear)) {
      years.add(_selectedYear);
      years.sort();
    }

    const months = <String, String>{
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

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search employee, ID, designation, team...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 560;

              final monthField = DropdownButtonFormField<String>(
                value: _selectedMonth,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Month',
                  prefixIcon: Icon(Icons.calendar_month_rounded, size: 19),
                ),
                items: months.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
                onChanged: _loading
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _selectedMonth = value);
                        _load();
                      },
              );

              final yearField = DropdownButtonFormField<String>(
                value: _selectedYear,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Year',
                ),
                items: years
                    .map(
                      (year) => DropdownMenuItem(
                        value: year,
                        child: Text(year),
                      ),
                    )
                    .toList(),
                onChanged: _loading
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _selectedYear = value);
                        _load();
                      },
              );

              final statusField = DropdownButtonFormField<String>(
                value: _selectedStatus,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Rating status',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'all',
                    child: Text('All employees'),
                  ),
                  DropdownMenuItem(
                    value: 'rated',
                    child: Text('Rated'),
                  ),
                  DropdownMenuItem(
                    value: 'not_rated',
                    child: Text('Not rated'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedStatus = value);
                },
              );

              if (narrow) {
                return Column(
                  children: [
                    monthField,
                    const SizedBox(height: 10),
                    yearField,
                    const SizedBox(height: 10),
                    statusField,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(flex: 2, child: monthField),
                  const SizedBox(width: 10),
                  Expanded(child: yearField),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: statusField),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeHeader() {
    final count = _filteredEmployees.length;

    return Row(
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.forest.withAlpha(18),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count employee${count == 1 ? '' : 's'}',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.forest,
            ),
          ),
        ),
      ],
    );
  }
}

/* ═══════════════════════════════════════════════════════════
   SCREEN SECTIONS
   ═══════════════════════════════════════════════════════════ */

class _SupervisorBanner extends StatelessWidget {
  final Supervisor supervisor;
  final PerformanceFilter filter;

  const _SupervisorBanner({
    required this.supervisor,
    required this.filter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.forestDeep, AppColors.forest],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(30),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.supervisor_account_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Performance Supervisor',
                  style: TextStyle(
                    fontSize: 9.5,
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  supervisor.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: display(
                    size: 16,
                    weight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  supervisor.designation,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  children: [
                    _WhiteTag('#${supervisor.empId}'),
                    _WhiteTag('${filter.month}/${filter.year}'),
                    if (filter.fromDate.isNotEmpty && filter.toDate.isNotEmpty)
                      _WhiteTag('${filter.fromDate} — ${filter.toDate}'),
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

class _SummarySection extends StatelessWidget {
  final PerformanceSummary summary;

  const _SummarySection({required this.summary});

  @override
  Widget build(BuildContext context) {
    final cards = [
      _SummaryCard(
        title: 'Employees',
        value: '${summary.totalEmployees}',
        subtitle: '${summary.rated} rated',
        icon: Icons.groups_rounded,
      ),
      _SummaryCard(
        title: 'Not Rated',
        value: '${summary.notRated}',
        subtitle: '${summary.ratedByMe} rated by me',
        icon: Icons.star_border_rounded,
      ),
      _SummaryCard(
        title: 'Team Average',
        value: summary.teamAverage == null
            ? '—'
            : summary.teamAverage!.toStringAsFixed(1),
        subtitle: 'out of $_maxRating',
        icon: Icons.star_rounded,
      ),
      _SummaryCard(
        title: 'Tasks',
        value: '${summary.totalTaskDone}/${summary.totalTask}',
        subtitle: '${summary.taskRate.toStringAsFixed(0)}% completed',
        icon: Icons.task_alt_rounded,
      ),
      _SummaryCard(
        title: 'Tours',
        value: '${summary.totalTour}',
        subtitle: 'for selected period',
        icon: Icons.route_rounded,
      ),
      _SummaryCard(
        title: 'Agendas',
        value: '${summary.agendaSubmitted}',
        subtitle: 'submitted',
        icon: Icons.event_note_rounded,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 800
            ? 3
            : constraints.maxWidth >= 500
                ? 3
                : 2;

        final width =
            (constraints.maxWidth - ((columns - 1) * 10)) / columns;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: cards
              .map(
                (card) => SizedBox(
                  width: width,
                  child: card,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  const _SummaryCard({
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
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  color: AppColors.forest.withAlpha(18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.forest, size: 18),
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
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 9.5,
              color: AppColors.mute,
            ),
          ),
        ],
      ),
    );
  }
}

/* ═══════════════════════════════════════════════════════════
   EMPLOYEE CARD
   ═══════════════════════════════════════════════════════════ */

class _EmployeePerformanceCard extends StatefulWidget {
  final EmployeePerformance item;
  final VoidCallback onRate;

  const _EmployeePerformanceCard({
    required this.item,
    required this.onRate,
  });

  @override
  State<_EmployeePerformanceCard> createState() =>
      _EmployeePerformanceCardState();
}

class _EmployeePerformanceCardState extends State<_EmployeePerformanceCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final employee = item.employee;
    final rating = item.rating.summary;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.forestDeep, AppColors.forest],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    employee.initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
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
                            _Tag(employee.portfolio, AppColors.forest),
                          if (employee.team.isNotEmpty)
                            _Tag(employee.team, AppColors.slate),
                          if (employee.location.isNotEmpty)
                            _Tag(employee.location, AppColors.mute),
                          _Tag('#${employee.empId}', AppColors.mute),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _RatingScore(summary: rating),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = (constraints.maxWidth - 8) / 2;

                final cards = [
                  _PerformanceMetric(
                    title: 'Tasks',
                    value: '${item.task.done}/${item.task.total}',
                    subtitle: '${item.task.doneRate.toStringAsFixed(0)}% done',
                    icon: Icons.task_alt_rounded,
                  ),
                  _PerformanceMetric(
                    title: 'Pending',
                    value: '${item.task.pending}',
                    subtitle: '${item.task.processing} processing',
                    icon: Icons.pending_actions_rounded,
                  ),
                  _PerformanceMetric(
                    title: 'Active Days',
                    value: '${item.task.activeDays}',
                    subtitle: item.task.lastActivity.isEmpty
                        ? 'No recent activity'
                        : 'Last: ${item.task.lastActivity}',
                    icon: Icons.calendar_today_rounded,
                  ),
                  _PerformanceMetric(
                    title: 'Tours',
                    value: '${item.tour.done}/${item.tour.total}',
                    subtitle: '${item.tour.tourDays} tour days',
                    icon: Icons.route_rounded,
                  ),
                ];

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: cards
                      .map(
                        (card) => SizedBox(
                          width: width,
                          child: card,
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ),
          if (rating.isRated)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: _RatingBreakdown(summary: rating),
            ),
          Padding(
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
                if (item.rating.ratedByMeReviews.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    icon: Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 18,
                    ),
                    label: Text(
                      _expanded
                          ? 'Hide Reviews'
                          : 'Reviews (${item.rating.ratedByMeReviews.length})',
                    ),
                  ),
                const SizedBox(width: 6),
                ElevatedButton.icon(
                  onPressed: widget.onRate,
                  icon: const Icon(Icons.star_rounded, size: 15),
                  label: Text(rating.isRated ? 'Rate Again' : 'Rate Now'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_expanded && item.rating.ratedByMeReviews.isNotEmpty) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  for (final review in item.rating.ratedByMeReviews) ...[
                    _ReviewCard(review: review),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RatingScore extends StatelessWidget {
  final RatingSummaryData summary;

  const _RatingScore({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 64),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: summary.isRated
            ? AppColors.amber.withAlpha(22)
            : AppColors.mute.withAlpha(12),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: summary.isRated
              ? AppColors.amber.withAlpha(80)
              : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          Icon(
            summary.isRated
                ? Icons.star_rounded
                : Icons.star_outline_rounded,
            color: summary.isRated ? AppColors.amber : AppColors.mute,
            size: 19,
          ),
          const SizedBox(height: 2),
          Text(
            summary.average == null
                ? '—'
                : summary.average!.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: summary.isRated
                  ? AppColors.forestDeep
                  : AppColors.mute,
            ),
          ),
          Text(
            summary.isRated
                ? '${summary.totalReview} review${summary.totalReview == 1 ? '' : 's'}'
                : 'Not rated',
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

class _PerformanceMetric extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  const _PerformanceMetric({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Container(
            width: 31,
            height: 31,
            decoration: BoxDecoration(
              color: AppColors.forest.withAlpha(17),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: AppColors.forest),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mute,
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
          ),
        ],
      ),
    );
  }
}

class _RatingBreakdown extends StatelessWidget {
  final RatingSummaryData summary;

  const _RatingBreakdown({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.amber.withAlpha(14),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.amber.withAlpha(50)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _RatingValue(
              label: 'RTA',
              value: summary.averageRta,
            ),
          ),
          const _VerticalLine(),
          Expanded(
            child: _RatingValue(
              label: 'Other',
              value: summary.averageOther,
            ),
          ),
          const _VerticalLine(),
          Expanded(
            child: _RatingValue(
              label: 'Highest',
              value: summary.highest,
            ),
          ),
          const _VerticalLine(),
          Expanded(
            child: _RatingValue(
              label: 'Lowest',
              value: summary.lowest,
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingValue extends StatelessWidget {
  final String label;
  final double? value;

  const _RatingValue({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value == null ? '—' : value!.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.forestDeep,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: const TextStyle(
            fontSize: 8.5,
            color: AppColors.mute,
          ),
        ),
      ],
    );
  }
}

class _VerticalLine extends StatelessWidget {
  const _VerticalLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 27,
      color: AppColors.border,
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final RatingReview review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.rate_review_outlined,
                size: 17,
                color: AppColors.forest,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  review.ratedBy.name.isEmpty
                      ? 'Rating review'
                      : review.ratedBy.name,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (review.average != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.amber.withAlpha(22),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 13,
                        color: AppColors.amber,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        review.average!.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '${review.date}${review.time.isEmpty ? '' : ' • ${review.time}'}',
            style: const TextStyle(
              fontSize: 9,
              color: AppColors.mute,
            ),
          ),
          const SizedBox(height: 10),
          _ReviewLine(
            label: 'RTA',
            rating: review.rtaRating,
            review: review.rtaReview,
          ),
          const SizedBox(height: 7),
          _ReviewLine(
            label: 'Other',
            rating: review.otherRating,
            review: review.otherReview,
          ),
        ],
      ),
    );
  }
}

class _ReviewLine extends StatelessWidget {
  final String label;
  final double? rating;
  final String review;

  const _ReviewLine({
    required this.label,
    required this.rating,
    required this.review,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 48,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.forestDeep,
            ),
          ),
        ),
        if (rating != null) ...[
          const Icon(Icons.star_rounded, size: 14, color: AppColors.amber),
          const SizedBox(width: 3),
          Text(
            rating!.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            review.isEmpty ? 'No review provided' : review,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.mute,
            ),
          ),
        ),
      ],
    );
  }
}

/* ═══════════════════════════════════════════════════════════
   RATING DIALOG
   ═══════════════════════════════════════════════════════════ */

class _RatingDialog extends StatefulWidget {
  final EmployeeInfo employee;
  final String supervisorId;
  final String month;
  final String year;

  const _RatingDialog({
    required this.employee,
    required this.supervisorId,
    required this.month,
    required this.year,
  });

  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  final _rtaReviewController = TextEditingController();
  final _otherReviewController = TextEditingController();

  double _rtaRating = 0;
  double _otherRating = 0;
  bool _saving = false;

  @override
  void dispose() {
    _rtaReviewController.dispose();
    _otherReviewController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rtaRating == 0 && _otherRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide at least one rating'),
          backgroundColor: AppColors.destructive,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await PerformanceApi.submitRating(
        employeeId: widget.employee.empId,
        supervisorId: widget.supervisorId,
        rtaRating: _rtaRating,
        rtaReview: _rtaReviewController.text.trim(),
        otherRating: _otherRating,
        otherReview: _otherReviewController.text.trim(),
        month: widget.month,
        year: widget.year,
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(21),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.forestDeep, AppColors.forest],
                  ),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(21),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 43,
                      height: 43,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(34),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        employee.initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
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
                            style: display(
                              size: 15,
                              weight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${employee.designation} • #${employee.empId}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _StarInput(
                      label: 'RTA Rating',
                      value: _rtaRating,
                      onChanged: (value) {
                        setState(() => _rtaRating = value);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _rtaReviewController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Write RTA review...',
                      ),
                    ),
                    const SizedBox(height: 17),
                    _StarInput(
                      label: 'Other Task Rating',
                      value: _otherRating,
                      onChanged: (value) {
                        setState(() => _otherRating = value);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _otherReviewController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Write other task review...',
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _submit,
                        icon: _saving
                            ? const SizedBox(
                                width: 17,
                                height: 17,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_rounded, size: 18),
                        label: Text(
                          _saving ? 'Saving...' : 'Submit Rating',
                        ),
                      ),
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

class _StarInput extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const _StarInput({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                value == 0
                    ? '—'
                    : '${value.toStringAsFixed(0)}/$_maxRating',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: value == 0 ? AppColors.mute : AppColors.forest,
                ),
              ),
            ],
          ),
          Row(
            children: [
              for (var index = 1; index <= _maxRating; index++)
                Expanded(
                  child: IconButton(
                    onPressed: () => onChanged(index.toDouble()),
                    icon: Icon(
                      index <= value
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 29,
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
   SHARED
   ═══════════════════════════════════════════════════════════ */

class _Tag extends StatelessWidget {
  final String label;
  final Color color;

  const _Tag(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _WhiteTag extends StatelessWidget {
  final String label;

  const _WhiteTag(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(28),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text(
            'Loading employee performance...',
            style: TextStyle(
              fontSize: 11.5,
              color: AppColors.mute,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 31,
            color: AppColors.mute,
          ),
          const SizedBox(height: 9),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.mute,
            ),
          ),
          const SizedBox(height: 13),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 17),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String message;

  const _EmptyState({
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(27),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.person_search_rounded,
            size: 33,
            color: AppColors.mute,
          ),
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
              fontSize: 10.5,
              color: AppColors.mute,
            ),
          ),
        ],
      ),
    );
  }
}
