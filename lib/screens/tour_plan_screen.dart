import 'dart:convert';

import 'package:calendar_view/calendar_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../api/api_models.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../theme.dart';
import '../widgets/pills.dart';
import 'tasks_screen.dart' show showTaskDetailsDialog;

const List<String> _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

const List<String> _tourPurposes = [
  'Sales Support',
  'Recovery Support',
  'Service Support',
  'On Job Training',
  'Marketing Activity',
  'Others',
];

class TourPlanScreen extends ConsumerStatefulWidget {
  const TourPlanScreen({super.key});

  @override
  ConsumerState<TourPlanScreen> createState() => _TourPlanScreenState();
}

class _TourPlanScreenState extends ConsumerState<TourPlanScreen> {
  List<CalendarEventData> _events = [];

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  void _loadEvents() {
    final tours = ref.read(myToursProvider).valueOrNull ?? [];
    _events = [];
    final now = DateTime.now();

    if (tours.isNotEmpty) {
      for (final t in tours) {
        final date = DateTime.tryParse(t.date) ?? now;
        _events.add(
          CalendarEventData(
            date: date,
            title: t.details,
            description: t.details,
            startTime: DateTime(date.year, date.month, date.day, 9, 0),
            endTime: DateTime(date.year, date.month, date.day, 17, 0),
          ),
        );
      }
    } else {
      _events.add(
        CalendarEventData(
          date: DateTime(now.year - 2, 1, 1),
          title: '',
          description: '',
          startTime: DateTime(now.year - 2, 1, 1, 9, 0),
          endTime: DateTime(now.year - 2, 1, 1, 10, 0),
        ),
      );
    }
  }

  List<CalendarEventData<Object?>> _hasEvent(
      DateTime date, List<CalendarEventData<Object?>> events) {
    final fmt = DateFormat('dd-MM-yyyy');
    return events.where((e) => fmt.format(e.date) == fmt.format(date)).toList();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(myToursProvider, (_, __) {
      if (mounted) setState(() => _loadEvents());
    });

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tour Plan',
                        style: display(
                            size: 24,
                            weight: FontWeight.w800,
                            color: AppColors.forestDeep)),
                    const Text('Plan tours by tapping on a calendar date.',
                        style: TextStyle(fontSize: 12, color: AppColors.mute)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                height: 620,
                child: MonthView(
                  headerBuilder: (date) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: Text(
                        DateFormat('MMMM yyyy').format(date),
                        style: display(size: 18, color: AppColors.forestDeep),
                      ),
                    ),
                  ),
                  controller:
                      EventController(eventFilter: (date, events) => _events),
                  borderColor: AppColors.border,
                  cellBuilder: (date, events, isToday, isInMonth, main) {
                    final eventList = _hasEvent(date, events);
                    if (!isInMonth) return const SizedBox.shrink();
                    return InkWell(
                      onTap: () => _openTourDialog(context, date),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border, width: 0.5),
                          color: isToday
                              ? AppColors.lime.withAlpha(30)
                              : Colors.white,
                        ),
                        child: Stack(
                          children: [
                            Align(
                              alignment: Alignment.topRight,
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Text(
                                  '${date.day}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isToday
                                        ? AppColors.forest
                                        : AppColors.text,
                                  ),
                                ),
                              ),
                            ),
                            if (eventList.isNotEmpty)
                              Align(
                                alignment: Alignment.center,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.amber.withAlpha(210),
                                  ),
                                  child: const Icon(Icons.directions_car,
                                      size: 20, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                  initialMonth: DateTime.now(),
                  cellAspectRatio: 1.4,
                  onPageChange: (_, __) {},
                  minMonth: DateTime.now(),
                  maxMonth: DateTime(DateTime.now().year + 2),
                  weekDayBuilder: (day) => Container(
                    decoration: BoxDecoration(
                      color: AppColors.forestDeep.withAlpha(20),
                      border: Border.all(color: AppColors.border, width: 0.5),
                    ),
                    child: Center(
                      child: Text(
                        _dayLabels[day],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: (day == 5 || day == 6)
                              ? AppColors.destructive
                              : AppColors.forestDeep,
                        ),
                      ),
                    ),
                  ),
                  startDay: WeekDays.sunday,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openTourDialog(BuildContext context, DateTime date) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final tours = ref.read(myToursProvider).valueOrNull ?? [];
    
    // Find all tours for this specific date
    final toursOnThisDay = tours.where((t) {
      final parsedDate = DateTime.tryParse(t.date);
      if (parsedDate == null) return false;
      return DateFormat('yyyy-MM-dd').format(parsedDate) == dateStr;
    }).toList();

    if (toursOnThisDay.isNotEmpty) {
      showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.forestDeep, AppColors.forest],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Tour Actions ($dateStr)',
                          style: display(size: 16, color: Colors.white, weight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showToursListDialog(context, dateStr, toursOnThisDay);
                        },
                        icon: const Icon(Icons.list_alt),
                        label: const Text('See Tours of this Day'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          showDialog<void>(
                            context: context,
                            builder: (_) => _TourCreationDialog(dateStr: dateStr),
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add New Tour'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      showDialog<void>(
        context: context,
        builder: (_) => _TourCreationDialog(dateStr: dateStr),
      );
    }
  }

  void _showToursListDialog(BuildContext context, String dateStr, List<TourModel> tours) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.forestDeep, AppColors.forest],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Tours on $dateStr',
                        style: display(size: 18, color: Colors.white, weight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: tours.length,
                  itemBuilder: (ctx, i) {
                    final t = tours[i];
                    final sCol = statusColor(t.isDone ? 'done' : 'todo');
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              width: 4,
                              color: sCol,
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  Navigator.pop(ctx);
                                  final raw = TaskModel(
                                    id: t.id,
                                    details: t.details,
                                    remarks: t.remarks,
                                    worktype: t.worktype,
                                    date: t.date,
                                    time: t.time,
                                    status: t.status,
                                    starttime: t.starttime,
                                    userid: t.userid,
                                    done: t.done,
                                    pending: t.pending,
                                    isAgenda: t.isAgenda,
                                    doneDate: t.doneDate,
                                    doneTime: t.doneTime,
                                    selectedTerritory: t.selectedTerritory,
                                  );
                                  showTaskDetailsDialog(context, ref, raw);
                                },
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(16),
                                  bottomRight: Radius.circular(16),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              t.details,
                                              style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          StatusPill(t.isDone ? 'done' : 'todo'),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Route: ${t.worktype} • ${t.remarks.isEmpty ? "No remarks" : t.remarks}',
                                        style: const TextStyle(fontSize: 12, color: AppColors.mute),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on, size: 12, color: AppColors.mute),
                                          const SizedBox(width: 3),
                                          Expanded(
                                            child: Text(
                                              t.selectedTerritory ?? 'No Territory',
                                              style: const TextStyle(fontSize: 11, color: AppColors.mute),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${t.date} ${t.time}',
                                            style: const TextStyle(fontSize: 11, color: AppColors.mute),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Footer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        showDialog<void>(
                          context: context,
                          builder: (_) => _TourCreationDialog(dateStr: dateStr),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add New Tour'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
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

class _TourCreationDialog extends ConsumerStatefulWidget {
  final String dateStr;
  const _TourCreationDialog({required this.dateStr});

  @override
  ConsumerState<_TourCreationDialog> createState() => _TourCreationDialogState();
}

class _TourCreationDialogState extends ConsumerState<_TourCreationDialog> {
  String _purpose = 'Sales Support';
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final List<String> _selectedTerritories = [];
  List<TerritoryModel> _filtered = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final all = ref.read(territoriesListProvider).valueOrNull ?? [];
    _filtered = all;
  }

  void _filter(String text) {
    final all = ref.read(territoriesListProvider).valueOrNull ?? [];
    setState(() {
      _filtered = all
          .where((t) => t.name.toLowerCase().contains(text.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final territories = ref.watch(territoriesListProvider).valueOrNull ?? [];
    if (_filtered.isEmpty && _searchController.text.isEmpty) {
      _filtered = territories;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.forestDeep,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add Tour Plan',
                          style: display(
                              size: 18,
                              weight: FontWeight.w700,
                              color: Colors.white)),
                      const SizedBox(height: 2),
                      Text('Date: ${widget.dateStr}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select Purpose',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.forestDeep)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _purpose,
                      decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10)),
                      items: _tourPurposes
                          .map((p) =>
                              DropdownMenuItem(value: p, child: Text(p)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _purpose = v ?? 'Sales Support'),
                    ),
                    if (_purpose == 'Others') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _remarksController,
                        decoration: const InputDecoration(
                            labelText: 'Remarks', hintText: 'Write here...'),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Text('Select Location (up to 3)',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.forestDeep)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _searchController,
                      onChanged: _filter,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search, size: 18),
                        hintText: 'Search territories...',
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_selectedTerritories.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: _selectedTerritories
                            .map((t) => Chip(
                                  label: Text(t,
                                      style: const TextStyle(fontSize: 11)),
                                  deleteIcon: const Icon(Icons.close, size: 14),
                                  onDeleted: () => setState(
                                      () => _selectedTerritories.remove(t)),
                                  backgroundColor: AppColors.lime.withAlpha(60),
                                ))
                            .toList(),
                      ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        itemCount: _filtered.length,
                        itemBuilder: (ctx, i) {
                          final name = _filtered[i].name;
                          final selected = _selectedTerritories.contains(name);
                          return ListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            title: Text(name,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w400)),
                            leading: Icon(
                              selected
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              size: 18,
                              color: selected
                                  ? AppColors.forest
                                  : AppColors.mute,
                            ),
                            onTap: () {
                              setState(() {
                                if (selected) {
                                  _selectedTerritories.remove(name);
                                } else if (_selectedTerritories.length < 3) {
                                  _selectedTerritories.add(name);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(
                    top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel',
                        style: TextStyle(color: AppColors.destructive)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: (_isSubmitting || _selectedTerritories.isEmpty)
                        ? null
                        : _submitTour,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Submit Tour'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitTour() async {
    setState(() => _isSubmitting = true);
    try {
      final session = ref.read(sessionControllerProvider)!;
      String lat = '', lan = '';
      try {
        final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 5));
        lat = pos.latitude.toString();
        lan = pos.longitude.toString();
      } catch (_) {}

      final details = _purpose == 'Others'
          ? _remarksController.text.trim()
          : _purpose;
      final territoryJson = jsonEncode(_selectedTerritories);

      final res = await ref.read(apiServiceProvider).addTask(
            userId: session.userId,
            worktype: 'Related to action plan',
            details: details,
            remarks: '',
            starttime: '1st Half',
            isAgenda: '2',
            selectedAgenda: '-1',
            selectedTerritory: territoryJson,
            postedDate: widget.dateStr,
            lat: lat,
            lan: lan,
          );
      if (!res.ok) throw Exception('Server rejected the tour');

      ref.invalidate(myTasksProvider);
      ref.invalidate(myToursProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Tour submitted successfully'),
          backgroundColor: AppColors.forest,
        ));
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: AppColors.destructive,
        ));
      }
    }
  }
}
