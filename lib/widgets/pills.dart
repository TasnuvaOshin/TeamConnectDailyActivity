import 'package:flutter/material.dart';
import '../theme.dart';

/// Fixed pill palette (§4.3):
/// priority — low slate · medium blue · high orange · urgent red
/// status — todo slate · in_progress blue · done green · overdue red
Color priorityColor(String p) => switch (p) {
      'urgent' => AppColors.red,
      'high' => AppColors.orange,
      'medium' => AppColors.blue,
      _ => AppColors.slate,
    };

Color statusColor(String s) => switch (s) {
      'done' => AppColors.green,
      'in_progress' => AppColors.blue,
      'overdue' => AppColors.red,
      _ => AppColors.slate,
    };

String statusLabel(String s) => switch (s) {
      'in_progress' => 'In progress',
      'done' => 'Done',
      'todo' => 'To do',
      _ => s,
    };

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  const Pill(this.text, {super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class PriorityPill extends StatelessWidget {
  final String priority;
  const PriorityPill(this.priority, {super.key});
  @override
  Widget build(BuildContext context) =>
      Pill(priority, color: priorityColor(priority));
}

class StatusPill extends StatelessWidget {
  final String status;
  const StatusPill(this.status, {super.key});
  @override
  Widget build(BuildContext context) =>
      Pill(statusLabel(status), color: statusColor(status));
}

/// KPI band pill: ≥100% lime · ≥80% moss · else amber (§5 Org tree).
class KpiPill extends StatelessWidget {
  final double pct;
  const KpiPill(this.pct, {super.key});
  @override
  Widget build(BuildContext context) {
    final color = pct >= 100
        ? const Color(0xFF6DA83C) // darkened lime for legibility
        : pct >= 80
            ? AppColors.moss
            : AppColors.amber;
    return Pill('${pct.round()}%', color: color);
  }
}
