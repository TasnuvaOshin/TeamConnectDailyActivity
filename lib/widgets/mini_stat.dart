import 'package:flutter/material.dart';
import '../theme.dart';

/// Rounded-2xl card with a small icon square top-left, big display value
/// and an uppercase micro label (§2.A.3).
class MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color tone;
  const MiniStat({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.tone = AppColors.forest,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: tone.withAlpha(31),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: tone),
          ),
          const SizedBox(height: 10),
          Text(value, style: display(size: 22, weight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w600,
              color: AppColors.mute,
            ),
          ),
        ],
      ),
    );
  }
}

/// White/15 chip used on the forest gradient banners (§2.B.1).
class StatChip extends StatelessWidget {
  final String label;
  final String value;
  const StatChip({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(38),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: display(
                  size: 18, weight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w600,
              color: Colors.white.withAlpha(191),
            ),
          ),
        ],
      ),
    );
  }
}
