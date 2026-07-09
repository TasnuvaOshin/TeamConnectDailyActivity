import 'package:flutter/material.dart';
import '../hierarchy.dart';
import '../models/profile.dart';

/// Rounded-square avatar tile filled with `levelColor(role_level)`,
/// initials = first letters of the first two words (§12.6).
class LevelAvatar extends StatelessWidget {
  final Profile profile;
  final double size;
  final double? radius;
  const LevelAvatar({
    super.key,
    required this.profile,
    this.size = 40,
    this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: levelColor(profile.roleLevel),
        borderRadius: BorderRadius.circular(radius ?? size * 0.3),
      ),
      alignment: Alignment.center,
      child: Text(
        profile.initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.34,
        ),
      ),
    );
  }
}

/// Small pulsing on-duty dot (lime with ring).
class OnDutyDot extends StatelessWidget {
  final double size;
  const OnDutyDot({super.key, this.size = 8});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFA6E663),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFA6E663).withAlpha(90),
            blurRadius: 0,
            spreadRadius: size * 0.35,
          ),
        ],
      ),
    );
  }
}
