import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/feedback.dart';
import '../models/kpi.dart';
import '../models/profile.dart';
import '../models/training.dart';
import '../providers/data_providers.dart';
import '../theme.dart';
import '../util/fmt.dart';

class GrowthScreen extends ConsumerWidget {
  const GrowthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpis = ref.watch(myKpisProvider).valueOrNull ?? const <Kpi>[];
    final trainings =
        ref.watch(myTrainingsProvider).valueOrNull ?? const <Training>[];
    final feedback =
        ref.watch(myFeedbackProvider).valueOrNull ?? const <FeedbackItem>[];
    final profiles =
        ref.watch(profilesMapProvider).valueOrNull ?? const <String, Profile>{};

    final withTarget = kpis.where((k) => k.target > 0).toList();
    final avg = withTarget.isEmpty
        ? null
        : withTarget.map((k) => k.pct).reduce((a, b) => a + b) /
            withTarget.length;
    final completedTrainings =
        trainings.where((t) => t.isCompleted).length;
    final wide = MediaQuery.of(context).size.width >= 900;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myKpisProvider);
        ref.invalidate(myTrainingsProvider);
        ref.invalidate(myFeedbackProvider);
        await Future<void>.delayed(const Duration(milliseconds: 250));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('My Growth',
              style: display(
                  size: 24,
                  weight: FontWeight.w800,
                  color: AppColors.forestDeep)),
          const Text('Targets, trainings and feedback over time.',
              style: TextStyle(fontSize: 12, color: AppColors.mute)),
          const SizedBox(height: 16),
          // 3-column stat grid (§8.2)
          Row(children: [
            Expanded(
              child: _GrowthStat(
                label: 'Average achievement',
                value: avg == null ? '—' : '${avg.round()}%',
                icon: Icons.workspace_premium_outlined,
                tone: AppColors.forestSoft,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _GrowthStat(
                label: 'Trainings completed',
                value: '$completedTrainings',
                icon: Icons.school_outlined,
                tone: AppColors.moss,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _GrowthStat(
                label: 'Feedback received',
                value: '${feedback.length}',
                icon: Icons.star_outline,
                tone: AppColors.amber,
              ),
            ),
          ]),
          const SizedBox(height: 16),
          // Target vs achievement (§8.3)
          if (withTarget.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Target vs achievement',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 8),
                    Row(children: [
                      _legendDot(AppColors.forestSoft, 'Target'),
                      const SizedBox(width: 14),
                      _legendDot(AppColors.amber, 'Achieved'),
                    ]),
                    const SizedBox(height: 12),
                    SizedBox(height: 256, child: _targetChart(withTarget)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          // Two-column area (§8.4)
          if (wide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _trainingsCard(trainings)),
              const SizedBox(width: 14),
              Expanded(child: _feedbackCard(feedback, profiles)),
            ])
          else ...[
            _trainingsCard(trainings),
            const SizedBox(height: 14),
            _feedbackCard(feedback, profiles),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _legendDot(Color c, String label) => Row(children: [
        Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppColors.mute)),
      ]);

  Widget _targetChart(List<Kpi> kpis) {
    final periods = kpis.map((k) => k.period).toSet().toList()..sort();
    final recent =
        periods.length > 6 ? periods.sublist(periods.length - 6) : periods;
    final data = <(String, double, double)>[];
    for (final p in recent) {
      final rows = kpis.where((k) => k.period == p);
      data.add((
        periodLabel(p),
        rows.fold<double>(0, (s, k) => s + k.target.toDouble()),
        rows.fold<double>(0, (s, k) => s + k.achieved.toDouble()),
      ));
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
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              getTitlesWidget: (v, _) => Text('${v.round()}',
                  style:
                      const TextStyle(fontSize: 10, color: AppColors.mute)),
            ),
          ),
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
                  color: AppColors.forestSoft,
                  width: 10,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3))),
              BarChartRodData(
                  toY: data[i].$3,
                  color: AppColors.amber,
                  width: 10,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3))),
            ]),
        ],
      ),
    );
  }

  Widget _trainingsCard(List<Training> trainings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Trainings',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 10),
            if (trainings.isEmpty)
              const Text('No trainings recorded yet.',
                  style: TextStyle(fontSize: 12, color: AppColors.mute)),
            for (final t in trainings)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  Icon(
                    t.isCompleted
                        ? Icons.check_circle_outline
                        : Icons.schedule,
                    size: 15,
                    color: t.isCompleted
                        ? AppColors.forestSoft
                        : AppColors.amber,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(t.title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13)),
                  ),
                  Text(
                    t.completedDate != null
                        ? DateFormat('d MMM yyyy').format(t.completedDate!)
                        : 'Planned',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.mute),
                  ),
                ]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _feedbackCard(
      List<FeedbackItem> feedback, Map<String, Profile> profiles) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Recent feedback',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 10),
            if (feedback.isEmpty)
              const Text('No feedback yet.',
                  style: TextStyle(fontSize: 12, color: AppColors.mute)),
            for (final f in feedback.take(8))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                          profiles[f.fromUser]?.fullName ?? '—',
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (f.rating != null)
                        Text('★' * f.rating!,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.amber)),
                    ]),
                    const SizedBox(height: 2),
                    Text(f.comment,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.mute)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GrowthStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color tone;
  const _GrowthStat(
      {required this.label,
      required this.value,
      required this.icon,
      required this.tone});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tone.withAlpha(31),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: tone),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: display(size: 19, weight: FontWeight.w800)),
                Text(label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.mute)),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
