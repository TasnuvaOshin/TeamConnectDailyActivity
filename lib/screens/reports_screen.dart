import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../hierarchy.dart';
import '../models/kpi.dart';
import '../models/profile.dart';
import '../models/task.dart';
import '../providers/data_providers.dart';
import '../theme.dart';
import '../util/fmt.dart';

class _ScoreRow {
  final Profile profile;
  final double kpiPct;
  final double completionRate;
  const _ScoreRow(this.profile, this.kpiPct, this.completionRate);

  /// Score formula (§7): pct·0.7 + completionRate·0.3
  int get score => (kpiPct * 0.7 + completionRate * 0.3).round();
}

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downline =
        ref.watch(downlineProvider).valueOrNull ?? const <Profile>[];
    final kpis = ref.watch(downlineKpisProvider).valueOrNull ?? const <Kpi>[];
    final tasks =
        ref.watch(downlineAllTasksProvider).valueOrNull ?? const <TaskItem>[];

    final rows = _scoreRows(downline, kpis, tasks);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reports',
                    style: display(
                        size: 24,
                        weight: FontWeight.w800,
                        color: AppColors.forestDeep)),
                const Text('Performance rollup across your chain.',
                    style: TextStyle(fontSize: 12, color: AppColors.mute)),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: rows.isEmpty
                ? null
                : () async {
                    await Clipboard.setData(
                        ClipboardData(text: _toCsv(rows)));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'team-report.csv copied to clipboard 📋')),
                      );
                    }
                  },
            icon: const Icon(Icons.download_outlined, size: 16),
            label: const Text('Export CSV'),
          ),
        ]),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.emoji_events_outlined,
                      size: 18, color: AppColors.amber),
                  SizedBox(width: 8),
                  Text('Top performers',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                ]),
                const SizedBox(height: 14),
                if (rows.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text('No team members visible yet.',
                        style:
                            TextStyle(fontSize: 13, color: AppColors.mute)),
                  )
                else ...[
                  // Header row
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      SizedBox(width: 26, child: _Th('#')),
                      Expanded(child: _Th('Employee')),
                      SizedBox(width: 52, child: _Th('KPI %', right: true)),
                      SizedBox(width: 56, child: _Th('Tasks %', right: true)),
                      SizedBox(width: 48, child: _Th('Score', right: true)),
                    ]),
                  ),
                  const Divider(height: 1),
                  for (var i = 0; i < rows.length && i < 20; i++)
                    _performerRow(i + 1, rows[i]),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _performerRow(int rank, _ScoreRow r) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(children: [
        SizedBox(
          width: 26,
          child: Text('$rank',
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.mute,
                  fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Row(children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: levelColor(r.profile.roleLevel),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.profile.fullName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w600)),
                  Text(r.profile.designation,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.mute)),
                ],
              ),
            ),
          ]),
        ),
        SizedBox(
            width: 52,
            child: Text('${r.kpiPct.round()}',
                textAlign: TextAlign.right,
                style: mono(size: 12))),
        SizedBox(
            width: 56,
            child: Text('${r.completionRate.round()}',
                textAlign: TextAlign.right,
                style: mono(size: 12))),
        SizedBox(
          width: 48,
          child: Text('${r.score}',
              textAlign: TextAlign.right,
              style: mono(size: 12.5, color: AppColors.amber)
                  .copyWith(fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  List<_ScoreRow> _scoreRows(
      List<Profile> downline, List<Kpi> kpis, List<TaskItem> tasks) {
    final period = currentPeriod();
    final rows = <_ScoreRow>[];
    for (final p in downline) {
      final myKpis = kpis
          .where((k) =>
              k.userId == p.id && k.period == period && k.target > 0)
          .toList();
      final pct = myKpis.isEmpty
          ? 0.0
          : myKpis.map((k) => k.pct).reduce((a, b) => a + b) / myKpis.length;
      final myTasks = tasks.where((t) => t.assigneeId == p.id).toList();
      final done = myTasks.where((t) => !t.isOpen).length;
      final completion =
          myTasks.isEmpty ? 0.0 : done * 100.0 / myTasks.length;
      rows.add(_ScoreRow(p, pct, completion));
    }
    rows.sort((a, b) => b.score.compareTo(a.score));
    return rows;
  }

  String _toCsv(List<_ScoreRow> rows) {
    final b = StringBuffer(
        'Name, Designation, Level, Department, Zone, KPI %, Task Completion %, Score\n');
    for (final r in rows) {
      b.writeln([
        r.profile.fullName,
        r.profile.designation,
        r.profile.roleLevel,
        r.profile.department ?? '',
        r.profile.zone ?? '',
        r.kpiPct.round(),
        r.completionRate.round(),
        r.score,
      ].map((v) => '"$v"').join(','));
    }
    return b.toString();
  }
}

class _Th extends StatelessWidget {
  final String text;
  final bool right;
  const _Th(this.text, {this.right = false});
  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: right ? TextAlign.right : TextAlign.left,
        style: const TextStyle(
            fontSize: 11,
            color: AppColors.mute,
            fontWeight: FontWeight.w600),
      );
}
