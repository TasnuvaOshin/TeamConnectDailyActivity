import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../hierarchy.dart';
import '../models/activity.dart';
import '../models/attendance.dart';
import '../models/kpi.dart';
import '../models/profile.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../theme.dart';
import '../util/fmt.dart';
import '../util/geo.dart';
import '../widgets/mini_stat.dart';
import '../widgets/pills.dart';
import '../widgets/quick_assign_dialog.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myProfileProvider);
    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (p) {
        if (p == null) return const Center(child: Text('No profile'));
        return isObserver(p.roleLevel)
            ? const ObserverDashboard()
            : const FieldDashboard();
      },
    );
  }
}

/* ═══════════════════ Shared: greeting header (§2.A.1 / §2.B) ═══════════════════ */

class GreetingHeader extends ConsumerWidget {
  final Profile profile;
  final String subLine;
  const GreetingHeader({
    super.key,
    required this.profile,
    required this.subLine,
  });

  void _showSignOutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text(
          'Are you sure you want to sign out from Team Connect?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(sessionControllerProvider.notifier).logout();
              if (context.mounted) context.go('/auth');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.destructive,
            ),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstName = profile.fullName.trim().split(RegExp(r'\s+')).first;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    size: 13,
                    color: AppColors.forest,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    banglaGreeting().toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.forest,
                      fontSize: 10,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '$firstName, ${profile.designation}',
                style: display(size: 22, weight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                subLine,
                style: const TextStyle(fontSize: 11, color: AppColors.mute),
              ),
            ],
          ),
        ),
        Tooltip(
          message: 'Sign out',
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _showSignOutDialog(context, ref),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: levelColor(profile.roleLevel),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Text(
                profile.initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/* ═══════════════════ Field dashboard (L13–17) — §2.A ═══════════════════ */

enum _GeoState { locating, inside, outside, denied, unavailable }

class FieldDashboard extends ConsumerStatefulWidget {
  const FieldDashboard({super.key});
  @override
  ConsumerState<FieldDashboard> createState() => _FieldDashboardState();
}

class _FieldDashboardState extends ConsumerState<FieldDashboard> {
  Timer? _gpsTimer;
  Timer? _clockTimer;
  _GeoState _geo = _GeoState.locating;
  double? _distanceMeters;
  double? _accuracyMeters;

  @override
  void initState() {
    super.initState();
    _tick();
    _gpsTimer = Timer.periodic(const Duration(seconds: 30), (_) => _tick());
    _clockTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => mounted ? setState(() {}) : null,
    );
  }

  @override
  void dispose() {
    _gpsTimer?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _tick() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) setState(() => _geo = _GeoState.unavailable);
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (mounted) setState(() => _geo = _GeoState.denied);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 8),
      );
      final dist = distanceFromAciCenter(pos.latitude, pos.longitude);
      final inside = dist <= geofenceRadiusMeters;
      if (mounted) {
        setState(() {
          _geo = inside ? _GeoState.inside : _GeoState.outside;
          _distanceMeters = dist;
          _accuracyMeters = pos.accuracy;
        });
      }
      await _autoAttendance(pos.latitude, pos.longitude, inside);
    } catch (_) {
      if (mounted) setState(() => _geo = _GeoState.unavailable);
    }
  }

  /// LOCAL: the third-party API has no attendance endpoints, so GPS
  /// check-in/out is stored on the device only.
  Future<void> _autoAttendance(double lat, double lng, bool inside) async {
    final session = ref.read(sessionControllerProvider);
    if (session == null) return;
    final store = ref.read(localAttendanceProvider);
    final today = DateTime.now();
    final existing = await store.forDay(session.userId, today);
    if (existing == null && inside) {
      await store.checkIn(today, note: 'Auto check-in (geofence)');
      ref.invalidate(myAttendanceTodayProvider);
      _toast('Auto check-in — welcome to ACI Centre 🌿');
    } else if (existing != null &&
        existing.checkIn != null &&
        existing.checkOut == null &&
        !inside) {
      await store.checkOut(today, note: 'Auto check-out (left geofence)');
      ref.invalidate(myAttendanceTodayProvider);
      _toast('Auto check-out — safe travels 🏁');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _manualCheckIn() async {
    await ref
        .read(localAttendanceProvider)
        .checkIn(DateTime.now(), note: 'Manual check-in');
    ref.invalidate(myAttendanceTodayProvider);
    _toast('Checked in — have a great day 🌿');
  }

  Future<void> _manualCheckOut(Attendance att) async {
    await ref.read(localAttendanceProvider).checkOut(DateTime.now());
    ref.invalidate(myAttendanceTodayProvider);
    _toast('Checked out — safe travels 🏁');
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(myProfileProvider).valueOrNull;
    final att = ref.watch(myAttendanceTodayProvider).valueOrNull;
    final activities =
        ref.watch(myActivitiesTodayProvider).valueOrNull ?? const <Activity>[];
    final openTasks = ref.watch(myOpenTasksProvider).valueOrNull ?? const [];
    final kpis = ref.watch(myKpisProvider).valueOrNull ?? const <Kpi>[];
    final teamActs =
        ref.watch(teamActivitiesTodayProvider).valueOrNull ??
        const <Activity>[];
    final profiles =
        ref.watch(profilesMapProvider).valueOrNull ?? const <String, Profile>{};

    if (profile == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final breakUsed = activities.fold<int>(0, (sum, a) => sum + a.breakMinutes);
    final kpiPct = _periodPct(kpis, currentPeriod());
    final trend = _trendPoints(kpis);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myAttendanceTodayProvider);
        ref.invalidate(myActivitiesTodayProvider);
        ref.invalidate(myOpenTasksProvider);
        ref.invalidate(myKpisProvider);
        ref.invalidate(teamActivitiesTodayProvider);
        await Future<void>.delayed(const Duration(milliseconds: 250));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GreetingHeader(
            profile: profile,
            subLine:
                '${profile.employeeId ?? '—'} · ${profile.department ?? '—'} · ${profile.zone ?? '—'}',
          ),
          const SizedBox(height: 20),
          _attendanceBanner(att, breakUsed),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: MiniStat(
                  label: 'Open tasks',
                  value: '${openTasks.length}',
                  icon: Icons.checklist_rtl,
                  tone: AppColors.forest,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MiniStat(
                  label: 'Logs today',
                  value: '${activities.length}',
                  icon: Icons.schedule_outlined,
                  tone: AppColors.moss,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MiniStat(
                  label: 'This month',
                  value: kpiPct == null ? '—' : '${kpiPct.round()}%',
                  icon: Icons.speed,
                  tone: AppColors.forestSoft,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  title: 'Log activity',
                  subtitle: 'Add to your timed day',
                  icon: Icons.add,
                  tileColor: AppColors.forestDeep,
                  iconColor: Colors.white,
                  onTap: () => context.go('/activities'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickAction(
                  title: 'My tasks',
                  subtitle: '${openTasks.length} open',
                  icon: Icons.list_alt,
                  tileColor: AppColors.lime,
                  iconColor: AppColors.forestDeep,
                  onTap: () => context.go('/tasks'),
                ),
              ),
            ],
          ),
          if (trend.length >= 2) ...[
            const SizedBox(height: 20),
            _card(
              title: 'Achievement trend',
              child: SizedBox(
                height: 160,
                child: _TrendLineChart(points: trend, showGrid: false),
              ),
            ),
          ],
          if (openTasks.isNotEmpty) ...[
            const SizedBox(height: 20),
            _card(
              title: 'Your open tasks',
              child: Column(
                children: [
                  for (final t in openTasks.take(4))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () async {
                              final session = ref.read(
                                sessionControllerProvider,
                              );
                              if (session == null) return;
                              if (session.isDemo) {
                                // STATIC: demo inbox lives in memory only.
                                ref
                                    .read(demoInboxTasksProvider.notifier)
                                    .setStatus(t.id, 'done');
                              } else {
                                // API: task/update2.php marks the task done.
                                await ref
                                    .read(apiServiceProvider)
                                    .updateTask(taskId: t.id);
                              }
                              ref.invalidate(myTasksProvider);
                              _toast('Task completed ✅');
                            },
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.forest,
                                  width: 1.6,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              t.title,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          PriorityPill(t.priority),
                          if (t.dueDate != null) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.schedule,
                              size: 12,
                              color: AppColors.mute,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              fmtDeadline(t.dueDate!),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.mute,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (activities.isNotEmpty) ...[
            const SizedBox(height: 20),
            _card(
              title: "Today's timeline",
              child: Column(
                children: [
                  for (final a in activities.take(5)) _TimelineRow(activity: a),
                ],
              ),
            ),
          ],
          // if (teamActs.isNotEmpty) ...[
          //   const SizedBox(height: 20),
          //   _card(
          //     title: 'Team is working on…',
          //     child: Column(children: [
          //       for (final a in teamActs.take(6))
          //         _TeamFeedRow(activity: a, profile: profiles[a.userId]),
          //     ]),
          //   ),
          // ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Attendance banner — rounded-3xl forest gradient (§2.A.2).
  Widget _attendanceBanner(Attendance? att, int breakUsed) {
    final now = DateTime.now();
    final checkedIn = att?.checkIn != null;
    final checkedOut = att?.checkOut != null;
    final elapsed = checkedIn
        ? (att!.checkOut ?? now).difference(att.checkIn!)
        : Duration.zero;
    final dutyPct = (elapsed.inMinutes / const Duration(hours: 9).inMinutes)
        .clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.forestDeep, AppColors.forest],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.forestDeep.withAlpha(64),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fmtDayLong(now).toUpperCase(),
                      style: TextStyle(
                        color: Colors.white.withAlpha(204),
                        fontSize: 11,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fmtClock(now),
                      style: display(
                        size: 34,
                        weight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '9h duty · 1h break expected',
                      style: TextStyle(
                        color: Colors.white.withAlpha(179),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (!checkedIn)
                _bannerButton(
                  label: 'Check in',
                  icon: Icons.login,
                  bg: AppColors.lime,
                  fg: AppColors.forestDeep,
                  onTap: _manualCheckIn,
                )
              else if (!checkedOut)
                _bannerButton(
                  label: 'Check out',
                  icon: Icons.logout,
                  bg: Colors.white,
                  fg: AppColors.forestDeep,
                  onTap: () => _manualCheckOut(att!),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(38),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: AppColors.lime, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Day closed',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _geofenceStrip(),
          if (checkedIn) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                _dutyStat('In', fmtClock(att!.checkIn!)),
                const SizedBox(width: 16),
                _dutyStat('Elapsed', fmtDuration(elapsed)),
                const SizedBox(width: 16),
                _dutyStat(
                  'Out',
                  att.checkOut == null ? '—' : fmtClock(att.checkOut!),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: dutyPct,
                minHeight: 3,
                backgroundColor: Colors.white.withAlpha(38),
                valueColor: const AlwaysStoppedAnimation(AppColors.lime),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.coffee,
                      size: 13,
                      color: Colors.white.withAlpha(191),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Break $breakUsed/60m',
                      style: TextStyle(
                        color: Colors.white.withAlpha(191),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${(dutyPct * 100).round()}% of shift',
                  style: TextStyle(
                    color: Colors.white.withAlpha(191),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _bannerButton({
    required String label,
    required IconData icon,
    required Color bg,
    required Color fg,
    required VoidCallback onTap,
  }) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dutyStat(String label, String value) => Row(
    children: [
      Text(
        '$label: ',
        style: TextStyle(color: Colors.white.withAlpha(153), fontSize: 11),
      ),
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );

  /// Geofence strip states (§2.A.2).
  Widget _geofenceStrip() {
    IconData icon;
    Color iconColor;
    String label;
    Widget? trailing;
    switch (_geo) {
      case _GeoState.locating:
        icon = Icons.my_location;
        iconColor = Colors.white70;
        label = 'Locating…';
        break;
      case _GeoState.inside:
        icon = Icons.verified_user;
        iconColor = AppColors.lime;
        label = 'Inside ACI Centre';
        break;
      case _GeoState.denied:
        icon = Icons.location_off;
        iconColor = AppColors.amber;
        label = 'Location off — enable for auto check-in';
        break;
      case _GeoState.unavailable:
        icon = Icons.gps_off;
        iconColor = AppColors.amber;
        label = 'GPS unavailable';
        break;
      case _GeoState.outside:
        icon = Icons.navigation_outlined;
        iconColor = Colors.white;
        final km = ((_distanceMeters ?? 0) / 1000);
        label = '${km.toStringAsFixed(km >= 10 ? 0 : 1)} km from ACI Centre';
        if (_accuracyMeters != null) {
          trailing = Text(
            '±${_accuracyMeters!.round()}m',
            style: TextStyle(color: Colors.white.withAlpha(153), fontSize: 11),
          );
        }
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}

/* ═══════════════════ Observer dashboard (L1–12) — §2.B ═══════════════════ */

class ObserverDashboard extends ConsumerWidget {
  const ObserverDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).valueOrNull;
    final downline = ref.watch(downlineProvider).valueOrNull ?? const [];
    final att =
        ref.watch(downlineAttendanceTodayProvider).valueOrNull ??
        const <Attendance>[];
    final openTasks =
        ref.watch(downlineOpenTasksProvider).valueOrNull ?? const [];
    final kpis = ref.watch(downlineKpisProvider).valueOrNull ?? const <Kpi>[];
    final acts =
        ref.watch(downlineActivitiesTodayProvider).valueOrNull ??
        const <Activity>[];
    final profiles =
        ref.watch(profilesMapProvider).valueOrNull ?? const <String, Profile>{};

    if (profile == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final onDuty = att
        .where((a) => a.checkIn != null && a.checkOut == null)
        .length;
    final currentPct = _periodPct(kpis, currentPeriod());
    final trend = _trendPoints(kpis);
    final performers = _topPerformers(kpis, profiles);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(downlineProvider);
        ref.invalidate(downlineAttendanceTodayProvider);
        ref.invalidate(downlineOpenTasksProvider);
        ref.invalidate(downlineKpisProvider);
        ref.invalidate(downlineActivitiesTodayProvider);
        await Future<void>.delayed(const Duration(milliseconds: 250));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GreetingHeader(
            profile: profile,
            subLine: 'Command view · ${downline.length} people in your chain',
          ),
          const SizedBox(height: 20),
          // Command banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.forestDeep, AppColors.forest],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.forestDeep.withAlpha(64),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentPct == null ? '—' : '${currentPct.round()}%',
                            style: display(
                              size: 36,
                              weight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Team achievement this month',
                            style: TextStyle(
                              color: Colors.white.withAlpha(179),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Material(
                      color: AppColors.lime,
                      borderRadius: BorderRadius.circular(999),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => showQuickAssignDialog(context, ref),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add,
                                size: 16,
                                color: AppColors.forestDeep,
                              ),
                              SizedBox(width: 5),
                              Text(
                                'Assign',
                                style: TextStyle(
                                  color: AppColors.forestDeep,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: StatChip(
                        label: 'On duty',
                        value: '$onDuty/${downline.length}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatChip(
                        label: 'Logs today',
                        value: '${acts.length}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatChip(
                        label: 'Open tasks',
                        value: '${openTasks.length}',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (trend.length >= 2) ...[
            const SizedBox(height: 20),
            _card(
              title: 'Team achievement trend',
              child: SizedBox(
                height: 176,
                child: _TrendLineChart(points: trend, showGrid: true),
              ),
            ),
          ],
          if (performers.isNotEmpty) ...[
            const SizedBox(height: 20),
            _card(
              title: 'Top performers this month',
              trailing: InkWell(
                onTap: () => context.go('/reports'),
                child: const Text(
                  'Leaderboard →',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.forest,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              child: SizedBox(
                height: 160,
                child: _PerformersBarChart(performers: performers),
              ),
            ),
          ],
          if (openTasks.isNotEmpty) ...[
            const SizedBox(height: 20),
            _card(
              title: 'Team open tasks',
              child: Column(
                children: [
                  for (final t in openTasks.take(6))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.title,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${profiles[t.assigneeId]?.fullName ?? '—'} · ${profiles[t.assigneeId]?.designation ?? ''}'
                                  '${t.dueDate != null ? ' · due ${fmtDeadline(t.dueDate!)}' : ''}',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.mute,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _ReminderButton(taskId: t.id),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (acts.isNotEmpty) ...[
            const SizedBox(height: 20),
            _card(
              title: 'Team activity — today',
              child: Column(
                children: [
                  for (final a in acts.take(8))
                    InkWell(
                      onTap: () => context.go('/team/${a.userId}'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: levelColor(
                                  profiles[a.userId]?.roleLevel ?? 17,
                                ),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a.title,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '${profiles[a.userId]?.fullName ?? '—'} · ${categoryLabel(a.type)} · ${fmtClock(a.startedAt)}'
                                    '${a.location != null ? ' · ${a.location}' : ''}',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.mute,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: AppColors.mute,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Bell button — STATIC: the API has no reminder/comment endpoint, so this
/// is UI-only feedback (§2.B.4 behaviour preserved visually).
class _ReminderButton extends ConsumerWidget {
  final String taskId;
  const _ReminderButton({required this.taskId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'Send reminder',
      icon: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.forest.withAlpha(26),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.notifications_none,
          size: 15,
          color: AppColors.forest,
        ),
      ),
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reminder sent (demo — not synced)')),
        );
      },
    );
  }
}

/* ═══════════════════ Shared pieces ═══════════════════ */

Widget _card({required String title, required Widget child, Widget? trailing}) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}

/// Timeline row — mono start time, vertical bar (moss / amber for break).
class _TimelineRow extends StatelessWidget {
  final Activity activity;
  const _TimelineRow({required this.activity});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(fmtClock(activity.startedAt), style: mono(size: 12)),
          ),
          Container(
            width: 3,
            height: 30,
            decoration: BoxDecoration(
              color: activity.isBreak ? AppColors.amber : AppColors.moss,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (activity.location != null)
                  Text(
                    activity.location!,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: AppColors.mute),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamFeedRow extends StatelessWidget {
  final Activity activity;
  final Profile? profile;
  const _TeamFeedRow({required this.activity, this.profile});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: levelColor(profile?.roleLevel ?? 17),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${profile?.fullName ?? '—'} · ${categoryLabel(activity.type)}'
                  '${activity.location != null ? ' · ${activity.location}' : ''}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppColors.mute),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color tileColor;
  final Color iconColor;
  final VoidCallback onTap;
  const _QuickAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tileColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tileColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.mute,
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

/* ═══════════════════ KPI math + charts ═══════════════════ */

/// Average achievement % for one period, null when no data.
double? _periodPct(List<Kpi> kpis, String period) {
  final rows = kpis.where((k) => k.period == period && k.target > 0).toList();
  if (rows.isEmpty) return null;
  return rows.map((k) => k.pct).reduce((a, b) => a + b) / rows.length;
}

/// (periodLabel, avgPct) for the last 6 periods present in the data.
List<MapEntry<String, double>> _trendPoints(List<Kpi> kpis) {
  final periods = kpis.map((k) => k.period).toSet().toList()..sort();
  final recent = periods.length > 6
      ? periods.sublist(periods.length - 6)
      : periods;
  final out = <MapEntry<String, double>>[];
  for (final p in recent) {
    final pct = _periodPct(kpis, p);
    if (pct != null) out.add(MapEntry(periodLabel(p), pct));
  }
  return out;
}

/// (firstName, currentMonthPct) sorted desc, top 6.
List<MapEntry<String, double>> _topPerformers(
  List<Kpi> kpis,
  Map<String, Profile> profiles,
) {
  final period = currentPeriod();
  final byUser = <String, List<Kpi>>{};
  for (final k in kpis.where((k) => k.period == period && k.target > 0)) {
    byUser.putIfAbsent(k.userId, () => []).add(k);
  }
  final entries = byUser.entries.map((e) {
    final pct =
        e.value.map((k) => k.pct).reduce((a, b) => a + b) / e.value.length;
    final name = profiles[e.key]?.fullName.split(' ').first ?? '—';
    return MapEntry(name, pct);
  }).toList()..sort((a, b) => b.value.compareTo(a.value));
  return entries.take(6).toList();
}

class _TrendLineChart extends StatelessWidget {
  final List<MapEntry<String, double>> points;
  final bool showGrid;
  const _TrendLineChart({required this.points, required this.showGrid});

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: showGrid,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: AppColors.border, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              getTitlesWidget: (v, _) => Text(
                '${v.round()}%',
                style: const TextStyle(fontSize: 10, color: AppColors.mute),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.round();
                if (i < 0 || i >= points.length || v != i.toDouble()) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    points[i].key,
                    style: const TextStyle(fontSize: 10, color: AppColors.mute),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  '${s.y.round()}%',
                  const TextStyle(color: Colors.white, fontSize: 11),
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            isCurved: true,
            color: AppColors.forestDeep,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                radius: 3.2,
                color: AppColors.lime,
                strokeColor: AppColors.forestDeep,
                strokeWidth: 1.2,
              ),
            ),
            spots: [
              for (var i = 0; i < points.length; i++)
                FlSpot(i.toDouble(), points[i].value),
            ],
          ),
        ],
      ),
    );
  }
}

class _PerformersBarChart extends StatelessWidget {
  final List<MapEntry<String, double>> performers;
  const _PerformersBarChart({required this.performers});

  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.round();
                if (i < 0 || i >= performers.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    performers[i].key,
                    style: const TextStyle(fontSize: 10, color: AppColors.mute),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (_, __, rod, ___) => BarTooltipItem(
              '${rod.toY.round()}%',
              const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < performers.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: performers[i].value,
                  color: AppColors.forest,
                  width: 18,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(5),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
