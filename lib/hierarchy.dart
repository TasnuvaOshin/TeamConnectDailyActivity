import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Levels 1–12 are observer bosses (no personal activity logging).
/// Levels 13–17 are field / PM roles that log daily activity.
const int observerMaxLevel = 12;

bool isObserver(int? level) =>
    level != null && level > 0 && level <= observerMaxLevel;

/// Navy → teal → green gradient by role level (§0.2):
///   hue = 220 + (155-220)·t, lightness = 22 + (52-22)·t,
///   saturation = 55 + 10·sin(π·t), where t = (L-1)/16.
Color levelColor(int level) {
  final l = level.clamp(1, 17);
  final t = (l - 1) / 16.0;
  final hue = 220 + (155 - 220) * t;
  final light = 22 + (52 - 22) * t;
  final sat = 55 + 10 * math.sin(math.pi * t);
  return HSLColor.fromAHSL(1, hue, sat / 100, light / 100).toColor();
}

const Map<int, String> designations = {
  1: 'Managing Director',
  2: 'Deputy Managing Director',
  3: 'Executive Director',
  4: 'Chief Business Officer',
  5: 'Business Director',
  6: 'Deputy Business Director',
  7: 'Business Manager',
  8: 'Senior GM',
  9: 'GM',
  10: 'Marketing Manager / DGM',
  11: 'Assistant Marketing Manager',
  12: 'Senior Product Manager',
  13: 'Product Manager',
  14: 'Deputy Product Manager',
  15: 'Assistant Manager',
  16: 'Senior Executive',
  17: 'Product Executive',
};
