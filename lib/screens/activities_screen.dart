import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../api/app_base.dart';
import '../hierarchy.dart';
import '../models/activity.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../theme.dart';
import '../util/fmt.dart';

const _filterChips = <String, String>{
  'all': 'All',
  'market_visit': 'Market Visit',
  'meeting': 'Meeting',
  'sales_call': 'Sales Call',
  'service_followup': 'Service Follow-up',
  'reporting': 'Reporting',
  'other': 'Other/Break',
};

class ActivitiesScreen extends ConsumerStatefulWidget {
  const ActivitiesScreen({super.key});
  @override
  ConsumerState<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends ConsumerState<ActivitiesScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(myProfileProvider).valueOrNull;

    // Observer branch (§3): empty-state card only.
    if (profile != null && isObserver(profile.roleLevel)) {
      return Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.forest.withAlpha(26),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.visibility_outlined,
                      color: AppColors.forest, size: 26),
                ),
                const SizedBox(height: 14),
                Text('Observer mode', style: display(size: 17)),
                const SizedBox(height: 6),
                const SizedBox(
                  width: 300,
                  child: Text(
                    'Levels 1–12 don\'t log personal activity. Watch your '
                    'team\'s day unfold from the team feed instead.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppColors.mute),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.go('/team'),
                  child: const Text('Open team feed'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final actsAsync = ref.watch(myActivitiesProvider);
    final acts = actsAsync.valueOrNull ?? const <Activity>[];
    final filtered = _filter == 'all'
        ? acts
        : acts.where((a) => a.type == _filter).toList();
    final groups = _groupByDay(filtered);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myActivitiesProvider);
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
                  Text('Daily Activity',
                      style: display(
                          size: 24,
                          weight: FontWeight.w800,
                          color: AppColors.forestDeep)),
                  const Text('9-hour duty · includes 1-hour break',
                      style:
                          TextStyle(fontSize: 12, color: AppColors.mute)),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _openLogDialog(context),
              icon: const Icon(Icons.add, size: 17),
              label: const Text('Log'),
            ),
          ]),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final e in _filterChips.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _FilterChip(
                    label: e.value,
                    active: _filter == e.key,
                    onTap: () => setState(() => _filter = e.key),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 16),
          if (actsAsync.isLoading && acts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (actsAsync.hasError && acts.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text('Could not load activities: ${actsAsync.error}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.destructive)),
              ),
            )
          else if (groups.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Center(
                  child: Text('No activities yet. Log your first one.',
                      style:
                          TextStyle(fontSize: 13, color: AppColors.mute)),
                ),
              ),
            ),
          for (final g in groups) ...[
            _DayHeader(day: g.key, activities: g.value),
            const SizedBox(height: 8),
            for (final a in g.value) ...[
              _ActivityCard(activity: a),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  List<MapEntry<DateTime, List<Activity>>> _groupByDay(List<Activity> acts) {
    final map = <DateTime, List<Activity>>{};
    for (final a in acts) {
      final day =
          DateTime(a.startedAt.year, a.startedAt.month, a.startedAt.day);
      map.putIfAbsent(day, () => []).add(a);
    }
    final entries = map.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    for (final e in entries) {
      e.value.sort((a, b) => a.startedAt.compareTo(b.startedAt));
    }
    return entries;
  }

  /// Log dialog — the third-party API only accepts a type code, details
  /// text and optional GPS, so the form is category + details.
  /// (Start/end times, break minutes, location and custom dates from the
  /// original design are NOT supported by the API.)
  Future<void> _openLogDialog(BuildContext context) async {
    final details = TextEditingController();
    String category = 'market_visit';
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Log a new activity', style: display(size: 18)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: [
                      for (final e in categoryLabels.entries)
                        DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ],
                    onChanged: (v) => setSt(() => category = v ?? 'other'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: details,
                    maxLines: 3,
                    onChanged: (_) => setSt(() {}),
                    decoration: const InputDecoration(
                        labelText: 'Details',
                        hintText: 'e.g. Dealer visit — Bashundhara'),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your GPS position is attached automatically when '
                    'available.',
                    style: TextStyle(fontSize: 11, color: AppColors.mute),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: details.text.trim().isEmpty || saving
                        ? null
                        : () async {
                            setSt(() => saving = true);
                            try {
                              await _submit(category, details.text.trim());
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
                        : const Text('Save activity'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit(String category, String details) async {
    final session = ref.read(sessionControllerProvider);
    if (session == null) return;

    if (session.isDemo) {
      // STATIC: demo sessions log to the in-memory list only.
      ref.read(demoActivitiesProvider.notifier).add(Activity(
            id: 'local-${DateTime.now().millisecondsSinceEpoch}',
            userId: session.userId,
            type: category,
            title: details,
            startedAt: DateTime.now(),
          ));
      ref.invalidate(myActivitiesProvider);
      return;
    }

    // API: GET activity/activity.php with best-effort GPS.
    String? lat;
    String? lan;
    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 5));
      lat = pos.latitude.toString();
      lan = pos.longitude.toString();
    } catch (_) {}

    final res = await ref.read(apiServiceProvider).submitActivity(
          userId: session.userId,
          typeCode: activityTypeToCode(category),
          details: details,
          lat: lat,
          lan: lan,
        );
    if (!res.ok) throw Exception('Server rejected the activity');
    ref.invalidate(myActivitiesProvider);
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.forestDeep : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color: active ? AppColors.forestDeep : AppColors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : AppColors.text,
            ),
          ),
        ),
      ),
    );
  }
}

/// Day heading. Duty/Coffee/Work strip renders only when the entries carry
/// end times (demo data); plain API rows show a log count instead.
class _DayHeader extends StatelessWidget {
  final DateTime day;
  final List<Activity> activities;
  const _DayHeader({required this.day, required this.activities});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final isToday = day.year == today.year &&
        day.month == today.month &&
        day.day == today.day;

    Duration duty = Duration.zero;
    var breakMin = 0;
    for (final a in activities) {
      duty += a.duration;
      breakMin += a.breakMinutes;
    }
    final hasDurations = duty.inMinutes > 0;
    final work = duty - Duration(minutes: breakMin);

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(children: [
        Expanded(
          child: Text(
            (isToday ? 'Today' : fmtDayShort(day)).toUpperCase(),
            style: const TextStyle(
              color: AppColors.forest,
              fontSize: 11,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (hasDurations) ...[
          Text('Duty ${fmtDuration(duty)}  ·  ',
              style: const TextStyle(fontSize: 11, color: AppColors.mute)),
          const Icon(Icons.coffee, size: 11, color: AppColors.amber),
          Text(' ${breakMin}m  ·  Work ',
              style: const TextStyle(fontSize: 11, color: AppColors.mute)),
          Text(fmtDuration(work),
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.forestDeep,
                  fontWeight: FontWeight.w700)),
        ] else
          Text('${activities.length} logs',
              style: const TextStyle(fontSize: 11, color: AppColors.mute)),
      ]),
    );
  }
}

/// Activity card — border-l-4 moss / amber for breaks (§3.5).
class _ActivityCard extends StatelessWidget {
  final Activity activity;
  const _ActivityCard({required this.activity});

  @override
  Widget build(BuildContext context) {
    final isBreak = activity.isBreak;
    return Container(
      decoration: BoxDecoration(
        color: isBreak ? const Color(0xFFFDF6EA) : Colors.white,
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
                  width: 4, color: isBreak ? AppColors.amber : AppColors.moss),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fmtClock(activity.startedAt), style: mono(size: 13)),
                    if (activity.endedAt != null)
                      Text(fmtClock(activity.endedAt!),
                          style: mono(size: 10, color: AppColors.mute)),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(activity.title,
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 5),
                      Wrap(spacing: 6, runSpacing: 4, children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.forestDeep.withAlpha(26),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            categoryLabel(activity.type).toUpperCase(),
                            style: const TextStyle(
                                fontSize: 9,
                                letterSpacing: 0.6,
                                fontWeight: FontWeight.w700,
                                color: AppColors.forestDeep),
                          ),
                        ),
                        if (isBreak)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.amber.withAlpha(38),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Break · ${activity.breakMinutes}m',
                              style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF9A6B1F)),
                            ),
                          ),
                      ]),
                      if (activity.notes != null &&
                          activity.notes!.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(activity.notes!,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.mute)),
                      ],
                      if (activity.location != null &&
                          activity.location!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.place_outlined,
                              size: 12, color: AppColors.mute),
                          const SizedBox(width: 3),
                          Text(activity.location!,
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.mute)),
                        ]),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
