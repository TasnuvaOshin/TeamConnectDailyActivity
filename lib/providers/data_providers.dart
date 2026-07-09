import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_models.dart';
import '../api/app_base.dart';
import '../data/local_attendance.dart';
import '../data/static_data.dart';
import '../hierarchy.dart';
import '../models/activity.dart';
import '../models/attendance.dart';
import '../models/feedback.dart';
import '../models/kpi.dart';
import '../models/profile.dart';
import '../models/task.dart';
import '../models/training.dart';
import '../util/fmt.dart';
import 'auth_provider.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Data providers after the third-party API migration.
///
///  · API-BACKED — activities (list/submit) and my tasks (list/add/done).
///  · LOCAL — attendance (device-only; the API has no attendance).
///  · STATIC — org hierarchy, downline stats, KPIs, trainings, feedback,
///    delegated tasks (in-memory demo data; see IMPLEMENTATION_STATUS.md).
/// ─────────────────────────────────────────────────────────────────────────

/* ═══════════════ Mapping helpers (API models → app models) ═══════════════ */

DateTime _parseApiDateTime(String date, String time) {
  return DateTime.tryParse('$date $time'.trim()) ??
      DateTime.tryParse('$date ${time.padLeft(5, '0')}:00'.trim()) ??
      DateTime.tryParse(date) ??
      DateTime.now();
}

Activity activityFromApi(ActivityDetailModel m) => Activity(
      id: m.id,
      userId: m.userid,
      type: activityCodeToType(m.type),
      title: m.details,
      startedAt: _parseApiDateTime(m.date, m.time),
      // Not provided by the API: endedAt, location, breakMinutes.
    );

TaskItem taskFromApi(TaskModel m) => TaskItem(
      id: m.id,
      title: m.details,
      description: [
        if (m.worktype.isNotEmpty) m.worktype,
        if (m.remarks.isNotEmpty) m.remarks,
      ].join(' · '),
      status: m.isDone
          ? 'done'
          : m.status.toLowerCase().contains('progress')
              ? 'in_progress'
              : 'todo',
      // The API has no assigner/assignee or priority — static defaults.
      priority: m.isAgenda == '1' ? 'high' : 'medium',
      assignerId: '',
      assigneeId: m.userid,
      dueDate: m.starttime.isNotEmpty
          ? DateTime.tryParse('${m.date} ${m.starttime}')
          : DateTime.tryParse(m.date),
      createdAt: _parseApiDateTime(m.date, m.time),
    );

/* ═══════════════ In-memory stores (STATIC, frontend-only) ═══════════════ */

class LocalTaskList extends StateNotifier<List<TaskItem>> {
  LocalTaskList(super.initial);
  void add(TaskItem t) => state = [t, ...state];
  void setStatus(String id, String status) => state = [
        for (final t in state)
          if (t.id == id)
            TaskItem(
              id: t.id,
              title: t.title,
              description: t.description,
              status: status,
              priority: t.priority,
              assignerId: t.assignerId,
              assigneeId: t.assigneeId,
              dueDate: t.dueDate,
              createdAt: t.createdAt,
            )
          else
            t
      ];
}

/// STATIC: demo inbox for offline demo sessions.
final demoInboxTasksProvider =
    StateNotifierProvider<LocalTaskList, List<TaskItem>>((ref) {
  final level = ref.watch(myLevelProvider);
  final twin = staticProfileForLevel(level);
  return LocalTaskList(
      staticOrgTasks().where((t) => t.assigneeId == twin.id).toList());
});

/// STATIC: "Delegated by me" — the API cannot assign tasks to other users,
/// so assignments live in memory for the session only.
final delegatedTasksProvider =
    StateNotifierProvider<LocalTaskList, List<TaskItem>>((ref) {
  final level = ref.watch(myLevelProvider);
  final twin = staticProfileForLevel(level);
  return LocalTaskList(
      staticOrgTasks().where((t) => t.assignerId == twin.id).toList());
});

class LocalActivityList extends StateNotifier<List<Activity>> {
  LocalActivityList(super.initial);
  void add(Activity a) => state = [a, ...state];
}

/// STATIC: demo activity log for offline demo sessions.
final demoActivitiesProvider =
    StateNotifierProvider<LocalActivityList, List<Activity>>((ref) {
  final session = ref.watch(sessionControllerProvider);
  if (session == null) return LocalActivityList(const []);
  return LocalActivityList(staticActivitiesToday(session.userId));
});

/* ═══════════════ My data ═══════════════ */

/// API-BACKED (demo sessions fall back to the in-memory list):
/// GET activity/get.php?id=&type=&all=0
final myActivitiesProvider = FutureProvider<List<Activity>>((ref) async {
  final session = ref.watch(sessionControllerProvider);
  if (session == null) return const [];
  if (session.isDemo) return ref.watch(demoActivitiesProvider);
  final rows =
      await ref.watch(apiServiceProvider).fetchActivities(userId: session.userId);
  return rows.map(activityFromApi).toList()
    ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
});

final myActivitiesTodayProvider = FutureProvider<List<Activity>>((ref) async {
  final all = await ref.watch(myActivitiesProvider.future);
  final now = DateTime.now();
  return all
      .where((a) =>
          a.startedAt.year == now.year &&
          a.startedAt.month == now.month &&
          a.startedAt.day == now.day)
      .toList()
    ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
});

final localAttendanceProvider =
    Provider<LocalAttendanceStore>((_) => LocalAttendanceStore());

/// LOCAL (device-only): the API has no attendance endpoints.
final myAttendanceTodayProvider = FutureProvider<Attendance?>((ref) async {
  final session = ref.watch(sessionControllerProvider);
  if (session == null) return null;
  return ref
      .watch(localAttendanceProvider)
      .forDay(session.userId, DateTime.now());
});

/// API-BACKED (demo sessions read the in-memory list):
/// GET task/get.php?id=
final myTasksProvider = FutureProvider<List<TaskItem>>((ref) async {
  final session = ref.watch(sessionControllerProvider);
  if (session == null) return const [];
  if (session.isDemo) return ref.watch(demoInboxTasksProvider);
  final rows = await ref.watch(apiServiceProvider).fetchTasks(session.userId);
  return rows.map(taskFromApi).toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
});

final myOpenTasksProvider = FutureProvider<List<TaskItem>>((ref) async {
  final tasks = await ref.watch(myTasksProvider.future);
  final open = tasks.where((t) => t.isOpen).toList()
    ..sort((a, b) {
      if (a.dueDate == null && b.dueDate == null) return 0;
      if (a.dueDate == null) return 1;
      if (b.dueDate == null) return -1;
      return a.dueDate!.compareTo(b.dueDate!);
    });
  return open;
});

/// STATIC: in-memory only (the API has no cross-user assignment).
final myDelegatedTasksProvider = FutureProvider<List<TaskItem>>((ref) async {
  return ref.watch(delegatedTasksProvider);
});

/// STATIC: KPIs are not exposed by the API.
final myKpisProvider = FutureProvider<List<Kpi>>((ref) async {
  final session = ref.watch(sessionControllerProvider);
  if (session == null) return const [];
  final level = ref.watch(myLevelProvider);
  return staticKpisFor(session.userId, level);
});

/// STATIC: feedback is not exposed by the API.
final myFeedbackProvider = FutureProvider<List<FeedbackItem>>((ref) async {
  final session = ref.watch(sessionControllerProvider);
  if (session == null) return const [];
  final level = ref.watch(myLevelProvider);
  return staticFeedbackFor(session.userId, level);
});

/// STATIC: trainings are not exposed by the API.
final myTrainingsProvider = FutureProvider<List<Training>>((ref) async {
  final session = ref.watch(sessionControllerProvider);
  if (session == null) return const [];
  return staticTrainingsFor(session.userId);
});

/* ═══════════════ Org / team data (all STATIC) ═══════════════ */

/// STATIC: demo org + the signed-in user.
final allProfilesProvider = FutureProvider<List<Profile>>((ref) async {
  final me = await ref.watch(myProfileProvider.future);
  return [
    if (me != null) me,
    ...staticOrg.where((p) => p.id != me?.id && p.employeeId != me?.employeeId),
  ];
});

final profilesMapProvider = FutureProvider<Map<String, Profile>>((ref) async {
  final all = await ref.watch(allProfilesProvider.future);
  final level = ref.watch(myLevelProvider);
  final me = await ref.watch(myProfileProvider.future);
  final map = {for (final p in all) p.id: p};
  // Alias my static twin to me so static task/feed rows resolve.
  if (me != null) map[staticProfileForLevel(level).id] = me;
  return map;
});

/// STATIC: everyone below my level in the demo chain.
final downlineProvider = FutureProvider<List<Profile>>((ref) async {
  final level = ref.watch(myLevelProvider);
  return staticDownlineOf(level);
});

/// STATIC: the next level down in the demo chain.
final directReportsProvider = FutureProvider<List<Profile>>((ref) async {
  final level = ref.watch(myLevelProvider);
  return staticDirectReportsOf(level);
});

/// STATIC assignment scope: observers → whole downline, others → directs.
final assignableProvider = FutureProvider<List<Profile>>((ref) async {
  final level = ref.watch(myLevelProvider);
  if (isObserver(level)) return staticDownlineOf(level);
  return staticDirectReportsOf(level);
});

/// STATIC: attendance today across the demo downline.
final downlineAttendanceTodayProvider =
    FutureProvider<List<Attendance>>((ref) async {
  final level = ref.watch(myLevelProvider);
  return staticDownlineAttendanceToday(level);
});

/// STATIC: open tasks across the demo downline + in-session assignments.
final downlineOpenTasksProvider = FutureProvider<List<TaskItem>>((ref) async {
  final level = ref.watch(myLevelProvider);
  final downIds = staticDownlineOf(level).map((p) => p.id).toSet();
  final delegated = ref.watch(delegatedTasksProvider);
  final seen = <String>{};
  return [
    ...delegated.where((t) => t.isOpen && downIds.contains(t.assigneeId)),
    ...staticOrgTasks()
        .where((t) => t.isOpen && downIds.contains(t.assigneeId)),
  ].where((t) => seen.add(t.id)).toList();
});

/// STATIC: every demo task under me (for report scoring).
final downlineAllTasksProvider = FutureProvider<List<TaskItem>>((ref) async {
  final level = ref.watch(myLevelProvider);
  final downIds = staticDownlineOf(level).map((p) => p.id).toSet();
  return staticOrgTasks()
      .where((t) => downIds.contains(t.assigneeId))
      .toList();
});

/// STATIC: today's activity feed across the demo downline.
final downlineActivitiesTodayProvider =
    FutureProvider<List<Activity>>((ref) async {
  final level = ref.watch(myLevelProvider);
  return staticDownlineActivitiesToday(level);
});

/// STATIC: 6 months of KPIs across the demo downline.
final downlineKpisProvider = FutureProvider<List<Kpi>>((ref) async {
  final level = ref.watch(myLevelProvider);
  return staticDownlineKpis(level);
});

/// STATIC: "Team is working on…" — demo field members other than me.
final teamActivitiesTodayProvider =
    FutureProvider<List<Activity>>((ref) async {
  final session = ref.watch(sessionControllerProvider);
  if (session == null) return const [];
  final level = ref.watch(myLevelProvider);
  final myTwin = staticProfileForLevel(level).id;
  return [
    for (final p in staticOrg)
      if (p.roleLevel > observerMaxLevel &&
          p.id != myTwin &&
          p.id != session.userId)
        ...staticActivitiesToday(p.id),
  ]..sort((a, b) => b.startedAt.compareTo(a.startedAt));
});

/// Current period helper re-export for screens.
String get thisPeriod => currentPeriod();

final myToursProvider = FutureProvider<List<TourModel>>((ref) async {
  final session = ref.watch(sessionControllerProvider);
  if (session == null || session.isDemo) return const [];
  return ref.watch(apiServiceProvider).fetchTours(session.userId);
});

final myCompletedTasksProvider = FutureProvider.family<List<TaskModel>, String>((ref, date) async {
  final session = ref.watch(sessionControllerProvider);
  if (session == null || session.isDemo) return const [];
  return ref.watch(apiServiceProvider).fetchCompletedTasks(session.userId, date);
});

final myAgendasProvider = FutureProvider<List<AgendaModel>>((ref) async {
  final session = ref.watch(sessionControllerProvider);
  if (session == null || session.isDemo) return const [];
  return ref.watch(apiServiceProvider).fetchAgendas(session.userId);
});

final territoriesListProvider = FutureProvider<List<TerritoryModel>>((ref) async {
  return ref.watch(apiServiceProvider).fetchTerritories();
});

final myRawTasksProvider = FutureProvider<List<TaskModel>>((ref) async {
  final session = ref.watch(sessionControllerProvider);
  if (session == null || session.isDemo) return const [];
  return ref.watch(apiServiceProvider).fetchTasks(session.userId);
});

