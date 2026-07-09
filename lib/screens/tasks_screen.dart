import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../api/api_models.dart' show AgendaModel, TerritoryModel, TaskModel;
import '../models/profile.dart';
import '../models/task.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../theme.dart';
import '../util/fmt.dart';
import '../widgets/pills.dart';
import '../widgets/quick_assign_dialog.dart';

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final assignable = ref.watch(assignableProvider).valueOrNull ?? const [];
    final canAssign = assignable.isNotEmpty;
    final inbox = ref.watch(myTasksProvider).valueOrNull ?? const <TaskItem>[];
    final delegated =
        ref.watch(myDelegatedTasksProvider).valueOrNull ?? const <TaskItem>[];
    final profiles =
        ref.watch(profilesMapProvider).valueOrNull ?? const <String, Profile>{};
    final isApiSession = session != null && !session.isDemo;

    final tabs = [
      const Tab(text: 'Assigned to me'),
      if (canAssign) const Tab(text: 'Delegated by me'),
      if (isApiSession) const Tab(text: 'Tours'),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myTasksProvider);
          if (isApiSession) {
            ref.invalidate(myToursProvider);
          }
          await Future<void>.delayed(const Duration(milliseconds: 250));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('My Tasks',
                        style: display(
                            size: 24,
                            weight: FontWeight.w800,
                            color: AppColors.forestDeep)),
                    const Text('Track your work and delegate to your team.',
                        style:
                            TextStyle(fontSize: 12, color: AppColors.mute)),
                  ],
                ),
              ),
              if (isApiSession) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: OutlinedButton.icon(
                    onPressed: () => _showCompletedTasksHistoryDialog(context, ref),
                    icon: const Icon(Icons.history, size: 16),
                    label: const Text('History'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: OutlinedButton.icon(
                    onPressed: () => _openAddTaskDialog(context, ref),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add task'),
                  ),
                ),
              ] else if (session != null && session.isDemo) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: OutlinedButton.icon(
                    onPressed: () => _openAddTaskDialog(context, ref),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add task'),
                  ),
                ),
              ],
              if (canAssign)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.amber),
                  onPressed: () => showQuickAssignDialog(context, ref),
                  icon: const Icon(Icons.add, size: 17),
                  label: const Text('Assign task'),
                ),
            ]),
            const SizedBox(height: 14),
            if (tabs.length > 1)
              TabBar(tabs: tabs),
            const SizedBox(height: 12),
            SizedBox(
              height: _tabHeight(inbox.length, delegated.length, isApiSession ? 5 : 0),
              child: TabBarView(children: [
                _InboxList(tasks: inbox, profiles: profiles),
                if (canAssign) _DelegatedList(tasks: delegated, profiles: profiles),
                if (isApiSession) const _ToursList(),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  double _tabHeight(int inbox, int delegated, int tours) {
    final a = (inbox * 132.0).clamp(140.0, double.infinity);
    final b = (delegated * 66.0).clamp(140.0, double.infinity);
    final c = (tours * 132.0).clamp(140.0, double.infinity);
    final maxAB = a > b ? a : b;
    return maxAB > c ? maxAB : c;
  }

  /// Task History Dialog (task/complete.php)
  Future<void> _showCompletedTasksHistoryDialog(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
    );
    if (pickedDate == null) return;
    final dateStr = pickedDate.toIso8601String().substring(0, 10);

    if (!context.mounted) return;
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
                        'Task History ($dateStr)',
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
                child: Consumer(
                  builder: (ctx, ref, _) {
                    final completedAsync = ref.watch(myCompletedTasksProvider(dateStr));
                    return completedAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, _) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Text('Error: $err', style: const TextStyle(color: AppColors.destructive)),
                        ),
                      ),
                      data: (tasks) {
                        if (tasks.isEmpty) {
                          return const Center(
                            child: Text(
                              'No tasks found for this date.',
                              style: TextStyle(color: AppColors.mute),
                            ),
                          );
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: tasks.length,
                          itemBuilder: (ctx, i) {
                            final t = tasks[i];
                            final priorityColor = t.isAgenda == '1' ? AppColors.forest : AppColors.mute.withAlpha(80);
                            final status = t.done == '1'
                                ? 'done'
                                : t.pending == '1'
                                    ? 'in_progress'
                                    : 'todo';
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
                                      color: priorityColor,
                                    ),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => showTaskDetailsDialog(context, ref, t),
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
                                                  StatusPill(status),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  const Icon(Icons.access_time, size: 12, color: AppColors.mute),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      [
                                                        if (t.worktype.isNotEmpty) t.worktype,
                                                        if (t.remarks.isNotEmpty) t.remarks,
                                                        if (t.starttime.isNotEmpty) t.starttime,
                                                        if (t.time.isNotEmpty) t.time,
                                                      ].join(' · '),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(fontSize: 11, color: AppColors.mute),
                                                    ),
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
                        );
                      },
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
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
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

  /// API-BACKED add-own-task dialog (task/add2.php) with Territory list (task/get_territory.php).
  Future<void> _openAddTaskDialog(BuildContext context, WidgetRef ref) async {
    final details = TextEditingController();
    final remarks = TextEditingController();
    String worktype = 'Related to action plan';
    String starttime = '1st Half';
    String isAgenda = '-1';
    String selectedAgenda = '-1';
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460, maxHeight: 600),
          child: StatefulBuilder(
            builder: (ctx, setSt) => Consumer(
              builder: (ctx, ref, _) {
                final session = ref.watch(sessionControllerProvider);
                final isApiSession = session != null && !session.isDemo;

                return Column(
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
                              'Add a Task',
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
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            DropdownButtonFormField<String>(
                              value: worktype,
                              decoration:
                                  const InputDecoration(labelText: 'Work type'),
                              items: const [
                                DropdownMenuItem(
                                    value: 'Related to action plan',
                                    child: Text('Related to action plan')),
                                DropdownMenuItem(
                                    value: 'Assigned by other',
                                    child: Text('Assigned by other')),
                                DropdownMenuItem(
                                    value: 'Others',
                                    child: Text('Others')),
                              ],
                              onChanged: (v) =>
                                  setSt(() => worktype = v ?? 'Related to action plan'),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: starttime,
                              decoration:
                                  const InputDecoration(labelText: 'Expected Start Time'),
                              items: const [
                                DropdownMenuItem(
                                    value: '1st Half', child: Text('1st Half')),
                                DropdownMenuItem(
                                    value: '2nd Half', child: Text('2nd Half')),
                              ],
                              onChanged: (v) =>
                                  setSt(() => starttime = v ?? '1st Half'),
                            ),

                            const SizedBox(height: 12),
                            TextField(
                              controller: details,
                              maxLines: 2,
                              onChanged: (_) => setSt(() {}),
                              decoration: InputDecoration(
                                labelText: 'Details *',
                                suffixIcon: isApiSession
                                    ? IconButton(
                                        icon: const Icon(Icons.add_box_rounded, color: AppColors.forest, size: 24),
                                        tooltip: 'Select from Monthly Agenda',
                                        onPressed: () {
                                          _showAgendaPicker(context, ref, (agenda) {
                                            setSt(() {
                                              details.text = agenda.agenda.replaceAll(RegExp(r"[,!&']"), '');
                                              isAgenda = '1';
                                              selectedAgenda = agenda.id;
                                            });
                                          });
                                        },
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text('(Avoid using any special characters)',
                                style: TextStyle(fontSize: 11, color: AppColors.destructive)),
                            const SizedBox(height: 12),
                            TextField(
                              controller: remarks,
                              decoration: const InputDecoration(labelText: 'Remarks'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Footer
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: AppColors.border)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel', style: TextStyle(color: AppColors.destructive)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: details.text.trim().isEmpty || saving
                                ? null
                                : () async {
                                    setSt(() => saving = true);
                                    try {
                                      final session =
                                          ref.read(sessionControllerProvider)!;
                                      
                                      String lat = '';
                                      String lan = '';
                                      try {
                                        final pos = await Geolocator.getCurrentPosition(
                                            desiredAccuracy: LocationAccuracy.medium,
                                            timeLimit: const Duration(seconds: 5));
                                        lat = pos.latitude.toString();
                                        lan = pos.longitude.toString();
                                      } catch (_) {}

                                      final detailsText = details.text.trim()
                                          .replaceAll('\u0027', '')
                                          .replaceAll(RegExp("/,|!|'&"), "");
                                      final remarksText = remarks.text.trim()
                                          .replaceAll('\u0027', '')
                                          .replaceAll(RegExp("/,|!|'&"), "");

                                      final res = await ref
                                          .read(apiServiceProvider)
                                          .addTask(
                                            userId: session.userId,
                                            worktype: worktype,
                                            details: detailsText,
                                            remarks: remarksText,
                                            starttime: starttime,
                                            isAgenda: isAgenda,
                                            selectedAgenda: selectedAgenda,
                                            selectedTerritory: 'none',
                                            lat: lat,
                                            lan: lan,
                                          );
                                      if (!res.ok) {
                                        throw Exception('Server rejected the task');
                                      }
                                      ref.invalidate(myTasksProvider);
                                      ref.invalidate(myRawTasksProvider);
                                      if (ctx.mounted) Navigator.pop(ctx);
                                    } catch (e) {
                                      setSt(() => saving = false);
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                            SnackBar(
                                                content: Text('Failed: $e'),
                                                backgroundColor:
                                                    AppColors.destructive));
                                      }
                                    }
                                  },
                            child: saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Text('Save Task'),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }
            ),
          ),
        ),
      ),
    );
  }
}

class _InboxList extends ConsumerWidget {
  final List<TaskItem> tasks;
  final Map<String, Profile> profiles;
  const _InboxList({required this.tasks, required this.profiles});


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final isApiSession = session != null && !session.isDemo;

    if (tasks.isEmpty) {
      return const Card(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Nothing assigned to you. Enjoy the calm 🌿',
                style: TextStyle(fontSize: 13, color: AppColors.mute)),
          ),
        ),
      );
    }
     return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tasks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final t = tasks[i];
        final overdue = t.isOpen &&
            t.dueDate != null &&
            t.dueDate!.isBefore(DateTime.now());
        final assigner = profiles[t.assignerId]?.fullName;
        final pCol = priorityColor(t.priority);

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () {
                final rawTasks = ref.read(myRawTasksProvider).valueOrNull ?? [];
                TaskModel? found;
                for (final r in rawTasks) {
                  if (r.id == t.id) {
                    found = r;
                    break;
                  }
                }
                final raw = found ??
                    TaskModel(
                      id: t.id,
                      details: t.title,
                      remarks: '',
                      worktype: '',
                      date: '',
                      time: '',
                      status: t.status,
                      starttime: '',
                      userid: t.assigneeId,
                      done: t.status == 'done' ? '1' : '0',
                      pending: t.status == 'in_progress' ? '1' : '0',
                      isAgenda: t.priority == 'high' ? '1' : '0',
                    );
                showTaskDetailsDialog(context, ref, raw);
              },
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 4,
                      color: pCol,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(t.title,
                                            style: const TextStyle(
                                                fontSize: 14, fontWeight: FontWeight.w600)),
                                      ),
                                      if (isApiSession) ...[
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: const Icon(Icons.edit, size: 14, color: AppColors.mute),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          tooltip: 'Edit details',
                                          onPressed: () => _openEditDetailsDialog(context, ref, t.id, t.title),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                PriorityPill(t.priority),
                                const SizedBox(width: 6),
                                StatusPill(overdue ? 'overdue' : t.status),
                              ],
                            ),
                            if (t.description != null && t.description!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(t.description!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12, color: AppColors.mute)),
                            ],
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                if (assigner != null)
                                  Text('From $assigner',
                                      style: const TextStyle(
                                          fontSize: 11, color: AppColors.mute)),
                                if (t.dueDate != null) ...[
                                  if (assigner != null) const SizedBox(width: 10),
                                  Icon(Icons.schedule,
                                      size: 12,
                                      color: overdue
                                          ? AppColors.destructive
                                          : AppColors.mute),
                                  const SizedBox(width: 3),
                                  Text(fmtDeadline(t.dueDate!),
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: overdue
                                              ? AppColors.destructive
                                              : AppColors.mute,
                                          fontWeight: overdue
                                              ? FontWeight.w700
                                              : FontWeight.w400)),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}


class _DelegatedList extends StatelessWidget {
  final List<TaskItem> tasks;
  final Map<String, Profile> profiles;
  const _DelegatedList({required this.tasks, required this.profiles});

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const Card(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('You haven\'t delegated any tasks yet.',
                style: TextStyle(fontSize: 13, color: AppColors.mute)),
          ),
        ),
      );
    }
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tasks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final t = tasks[i];
        final pCol = priorityColor(t.priority);
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 4,
                    color: pCol,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${t.title}  →  ${profiles[t.assigneeId]?.fullName ?? '—'}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                          const SizedBox(width: 8),
                          PriorityPill(t.priority),
                          const SizedBox(width: 6),
                          StatusPill(t.status == 'open' ? 'todo' : t.status),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ToursList extends ConsumerWidget {
  const _ToursList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toursAsync = ref.watch(myToursProvider);
    return toursAsync.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
      error: (err, _) => Card(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error loading tours: $err', style: const TextStyle(color: AppColors.destructive)),
          ),
        ),
      ),
      data: (tours) {
        if (tours.isEmpty) {
          return const Card(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No tours found.', style: TextStyle(fontSize: 13, color: AppColors.mute)),
              ),
            ),
          );
        }
        return ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tours.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final t = tours[i];
            final sCol = statusColor(t.isDone ? 'done' : 'todo');
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: () {
                    final rawTasks = ref.read(myRawTasksProvider).valueOrNull ?? [];
                    TaskModel? found;
                    for (final r in rawTasks) {
                      if (r.id == t.id) {
                        found = r;
                        break;
                      }
                    }
                    final raw = found ??
                        TaskModel(
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
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 4,
                          color: sCol,
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(t.details, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                    ),
                                    const SizedBox(width: 8),
                                    StatusPill(t.isDone ? 'done' : 'todo'),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text('Route / Info: ${t.worktype} • ${t.remarks.isEmpty ? "No remarks" : t.remarks}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.mute)),
                                const SizedBox(height: 10),
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
                                    Text('${t.date} ${t.time}', style: const TextStyle(fontSize: 11, color: AppColors.mute)),
                                    if (!t.isDone) ...[
                                      const SizedBox(width: 8),
                                      TextButton(
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        onPressed: () {
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
                                          _showTourUpdateDialog(context, ref, raw);
                                        },
                                        child: const Text('Update', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.forest)),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

Future<void> _openEditDetailsDialog(BuildContext context, WidgetRef ref, String taskId, String currentDetails) async {
  final controller = TextEditingController(text: currentDetails);
  bool saving = false;
  await showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 300),
        child: StatefulBuilder(
          builder: (ctx, setSt) => Column(
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
                        'Edit Task Details',
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
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: TextField(
                    controller: controller,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Details',
                      hintText: 'Task details...',
                    ),
                  ),
                ),
              ),
              // Footer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel', style: TextStyle(color: AppColors.destructive)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: saving ? null : () async {
                        setSt(() => saving = true);
                        try {
                          await ref.read(apiServiceProvider).updateTaskDetails(taskId, controller.text.trim());
                          ref.invalidate(myTasksProvider);
                          ref.invalidate(myRawTasksProvider);
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          setSt(() => saving = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.destructive));
                          }
                        }
                      },
                      child: saving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Save'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void _showAgendaPicker(BuildContext context, WidgetRef ref, Function(AgendaModel) onSelect) {
  showDialog<void>(
    context: context,
    builder: (ctx) {
      final agendasAsync = ref.watch(myAgendasProvider);
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450, maxHeight: 500),
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
                        'Select from Monthly Agenda',
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
              Expanded(
                child: agendasAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error: $err')),
                  data: (agendas) {
                    if (agendas.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No agenda items found for this month.', style: TextStyle(color: AppColors.mute)),
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: agendas.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, idx) {
                        final a = agendas[idx];
                        return Card(
                          color: AppColors.bg,
                          child: ListTile(
                            title: Text(a.agenda, style: const TextStyle(fontSize: 13)),
                            onTap: () {
                              onSelect(a);
                              Navigator.pop(ctx);
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> showTaskDetailsDialog(BuildContext context, WidgetRef ref, TaskModel task) async {
  final session = ref.read(sessionControllerProvider);
  final isApiSession = session != null && !session.isDemo;

  await showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: StatefulBuilder(
          builder: (ctx, setSt) {
            final isDone = task.done == '1' || task.status.toLowerCase() == 'done';
            final isProcessing = task.pending == '1' || task.status.toLowerCase() == 'in_progress';
            final statusStr = isDone ? 'Done' : (isProcessing ? 'Processing' : 'Pending');
            final statusColor = isDone
                ? AppColors.green
                : (isProcessing ? AppColors.orange : AppColors.blue);
            final percentText = isDone ? '100%' : (isProcessing ? '50%' : '0%');
            final percentVal = isDone ? 1.0 : (isProcessing ? 0.5 : 0.0);

            // Parse selected territories if tour task
            List<String> territoriesList = [];
            if (task.isAgenda == '2' && task.selectedTerritory != null) {
              try {
                final parsed = jsonDecode(task.selectedTerritory!);
                if (parsed is List) {
                  territoriesList = parsed.map((e) => e.toString()).toList();
                }
              } catch (_) {}
            }

            return Column(
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
                          'Task Details',
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
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Task ID: #2022${task.id}',
                              style: mono(size: 12, color: AppColors.mute),
                            ),
                            Text(
                              task.date,
                              style: const TextStyle(fontSize: 12, color: AppColors.mute),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          task.details,
                          style: display(size: 16, weight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 12),
                        _buildInfoRow('Work Type', task.worktype.isEmpty ? 'N/A' : task.worktype),
                        const SizedBox(height: 8),
                        _buildInfoRow('Expected Start', task.starttime.isEmpty ? 'N/A' : task.starttime),
                        const SizedBox(height: 8),
                        _buildInfoRow('Remarks', task.remarks.isEmpty ? 'None' : task.remarks),
                        if (task.isAgenda == '2') ...[
                          const SizedBox(height: 8),
                          _buildInfoRow('Target Territories', territoriesList.isEmpty ? 'None' : territoriesList.join(', ')),
                          if (task.visitedTerritory != null && task.visitedTerritory!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _buildInfoRow('Visited Territory', task.visitedTerritory!),
                          ],
                        ],
                        const SizedBox(height: 24),
                        // Status & Progress Card
                        Card(
                          color: AppColors.bg,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Status',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.forestDeep,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        statusStr,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: statusColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SizedBox(
                                      width: 60,
                                      height: 60,
                                      child: CircularProgressIndicator(
                                        value: percentVal,
                                        strokeWidth: 4.5,
                                        backgroundColor: AppColors.border,
                                        color: statusColor,
                                      ),
                                    ),
                                    Text(
                                      percentText,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: statusColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Footer
                if (isApiSession && !isDone)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _openEditDetailsDialog(context, ref, task.id, task.details);
                          },
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Edit Details'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {
                            if (task.isAgenda == '2') {
                              _showTourUpdateDialog(context, ref, task);
                            } else {
                              _showStatusUpdateDialog(context, ref, task);
                            }
                          },
                          child: const Text('Update Status'),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

Widget _buildInfoRow(String label, String value) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 120,
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.mute),
        ),
      ),
      Expanded(
        child: Text(
          value,
          style: const TextStyle(fontSize: 12, color: AppColors.text),
        ),
      ),
    ],
  );
}

void _showStatusUpdateDialog(BuildContext context, WidgetRef ref, TaskModel task) {
  String selected = 'Processing';
  bool submitting = false;

  showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 260),
        child: StatefulBuilder(
          builder: (ctx, setSt) => Column(
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
                        'Update Task Status',
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
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: DropdownButtonFormField<String>(
                    value: selected,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(value: 'Processing', child: Text('Processing')),
                      DropdownMenuItem(value: 'Done', child: Text('Done')),
                    ],
                    onChanged: (v) => setSt(() => selected = v ?? 'Processing'),
                  ),
                ),
              ),
              // Footer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel', style: TextStyle(color: AppColors.destructive)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: submitting
                          ? null
                          : () async {
                              setSt(() => submitting = true);
                              try {
                                String lat = '', lan = '';
                                try {
                                  final pos = await Geolocator.getCurrentPosition(
                                      desiredAccuracy: LocationAccuracy.medium,
                                      timeLimit: const Duration(seconds: 5));
                                  lat = pos.latitude.toString();
                                  lan = pos.longitude.toString();
                                } catch (_) {}

                                final typeCode = selected == 'Processing' ? '0' : '1';
                                final res = await ref.read(apiServiceProvider).updateTask(
                                      taskId: task.id,
                                      type: typeCode,
                                      visitedTerritory: 'none',
                                      lat: lat,
                                      lan: lan,
                                    );
                                if (!res.ok) throw Exception('Failed to update status');

                                ref.invalidate(myTasksProvider);
                                ref.invalidate(myRawTasksProvider);

                                if (ctx.mounted) {
                                  Navigator.pop(ctx); // Close update dialog
                                  Navigator.pop(context); // Close details dialog
                                }
                              } catch (e) {
                                setSt(() => submitting = false);
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.destructive));
                                }
                              }
                            },
                      child: submitting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Submit'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void _showTourUpdateDialog(BuildContext context, WidgetRef ref, TaskModel task) {
  String locationType = 'Head Office';
  final TextEditingController searchController = TextEditingController();
  final List<String> selectedTerritories = [];
  List<TerritoryModel> filteredTerritories = [];
  bool submitting = false;

  // Parse target territories from the tour task
  List<String> targetTerritories = [];
  if (task.selectedTerritory != null) {
    try {
      final parsed = jsonDecode(task.selectedTerritory!);
      if (parsed is List) {
        targetTerritories = parsed.map((e) => e.toString()).toList();
      }
    } catch (_) {}
  }

  // Pre-populate with target territories
  selectedTerritories.addAll(targetTerritories);

  showDialog<void>(
    context: context,
    builder: (ctx) {
      final allTerritories = ref.watch(territoriesListProvider).valueOrNull ?? [];
      if (filteredTerritories.isEmpty && searchController.text.isEmpty) {
        filteredTerritories = allTerritories;
      }

      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: StatefulBuilder(
            builder: (ctx, setSt) {
              void filter(String text) {
                setSt(() {
                  filteredTerritories = allTerritories
                      .where((t) => t.name.toLowerCase().contains(text.toLowerCase()))
                      .toList();
                });
              }

              return Column(
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
                            'Update Tour Status',
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
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Current Location',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.forestDeep),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: locationType,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Head Office', child: Text('Head Office')),
                              DropdownMenuItem(value: 'On Tour', child: Text('On Tour')),
                            ],
                            onChanged: (v) => setSt(() => locationType = v ?? 'Head Office'),
                          ),
                          if (locationType == 'On Tour') ...[
                            const SizedBox(height: 16),
                            const Text(
                              'Select Visited Territories (up to 3)',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.forestDeep),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: searchController,
                              onChanged: filter,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.search, size: 18),
                                hintText: 'Search territories...',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (selectedTerritories.isNotEmpty)
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: selectedTerritories
                                    .map((t) => Chip(
                                          label: Text(t, style: const TextStyle(fontSize: 11)),
                                          deleteIcon: const Icon(Icons.close, size: 14),
                                          onDeleted: () => setSt(() => selectedTerritories.remove(t)),
                                          backgroundColor: AppColors.lime.withAlpha(60),
                                        ))
                                    .toList(),
                              ),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 180,
                              child: ListView.builder(
                                itemCount: filteredTerritories.length,
                                itemBuilder: (ctx, i) {
                                  final name = filteredTerritories[i].name;
                                  final selected = selectedTerritories.contains(name);
                                  return ListTile(
                                    dense: true,
                                    visualDensity: VisualDensity.compact,
                                    title: Text(name, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w700 : FontWeight.w400)),
                                    leading: Icon(
                                      selected ? Icons.check_circle : Icons.circle_outlined,
                                      size: 18,
                                      color: selected ? AppColors.forest : AppColors.mute,
                                    ),
                                    onTap: () {
                                      setSt(() {
                                        if (selected) {
                                          selectedTerritories.remove(name);
                                        } else if (selectedTerritories.length < 3) {
                                          selectedTerritories.add(name);
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  // Footer
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel', style: TextStyle(color: AppColors.destructive)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: submitting || (locationType == 'On Tour' && selectedTerritories.isEmpty)
                              ? null
                              : () async {
                                  setSt(() => submitting = true);
                                  try {
                                    String lat = '', lan = '';
                                    try {
                                      final pos = await Geolocator.getCurrentPosition(
                                          desiredAccuracy: LocationAccuracy.medium,
                                          timeLimit: const Duration(seconds: 5));
                                      lat = pos.latitude.toString();
                                      lan = pos.longitude.toString();
                                    } catch (_) {}

                                    final visitedTerritory = locationType == 'Head Office' ? 'HO' : jsonEncode(selectedTerritories);

                                    final res = await ref.read(apiServiceProvider).updateTask(
                                          taskId: task.id,
                                          type: '1',
                                          visitedTerritory: visitedTerritory,
                                          lat: lat,
                                          lan: lan,
                                        );
                                    if (!res.ok) throw Exception('Failed to update tour status');

                                    ref.invalidate(myTasksProvider);
                                    ref.invalidate(myToursProvider);
                                    ref.invalidate(myRawTasksProvider);

                                    if (ctx.mounted) {
                                      Navigator.pop(ctx); // Close tour dialog
                                      Navigator.pop(context); // Close details dialog
                                    }
                                  } catch (e) {
                                    setSt(() => submitting = false);
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.destructive));
                                    }
                                  }
                                },
                          child: submitting
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Submit'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    },
  );
}
