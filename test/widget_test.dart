import 'package:flutter_test/flutter_test.dart';

import 'package:team_connect/api/app_base.dart';
import 'package:team_connect/data/static_data.dart';
import 'package:team_connect/hierarchy.dart';
import 'package:team_connect/util/fmt.dart';
import 'package:team_connect/util/geo.dart';

void main() {
  group('hierarchy', () {
    test('levels 1–12 are observers, 13–17 are field', () {
      expect(isObserver(1), isTrue);
      expect(isObserver(12), isTrue);
      expect(isObserver(13), isFalse);
      expect(isObserver(17), isFalse);
      expect(isObserver(null), isFalse);
      expect(isObserver(0), isFalse);
    });

    test('all 17 designations are mapped', () {
      expect(designations.length, 17);
      expect(designations[1], 'Managing Director');
      expect(designations[17], 'Product Executive');
    });
  });

  group('static org', () {
    test('demo org has one profile per level in a manager chain', () {
      expect(staticOrg.length, 17);
      expect(staticOrg.first.managerId, isNull);
      for (var i = 1; i < 17; i++) {
        expect(staticOrg[i].managerId, staticOrg[i - 1].id);
      }
    });

    test('designation → level mapping falls back to 17', () {
      expect(designationToLevel('Managing Director'), 1);
      expect(designationToLevel('GM'), 9);
      expect(designationToLevel('Mobile Application Developer'), 17);
    });

    test('static KPIs cover 6 periods with sane values', () {
      final kpis = staticKpisFor('static-013', 13);
      expect(kpis.length, 6);
      for (final k in kpis) {
        expect(k.target, greaterThan(0));
        expect(k.achieved, greaterThan(0));
      }
    });
  });

  group('api mapping', () {
    test('activity type codes round-trip', () {
      for (final slug in activityTypeCodes.keys) {
        expect(activityCodeToType(activityTypeToCode(slug)), slug);
      }
      expect(activityCodeToType('999'), 'other');
    });
  });

  group('geo', () {
    test('inside the 150 m ACI Centre geofence', () {
      expect(insideAciCenter(aciCenterLat, aciCenterLng), isTrue);
      expect(insideAciCenter(aciCenterLat + 0.01, aciCenterLng), isFalse);
    });
  });

  group('fmt', () {
    test('Bangla greeting bands', () {
      expect(banglaGreeting(DateTime(2026, 7, 7, 9)), 'Shuprobhat');
      expect(banglaGreeting(DateTime(2026, 7, 7, 13)), 'Shubho oporahno');
      expect(banglaGreeting(DateTime(2026, 7, 7, 19)), 'Shubho shondha');
    });

    test('duration formatting', () {
      expect(fmtDuration(const Duration(hours: 6, minutes: 45)), '6h 45m');
      expect(fmtDuration(const Duration(minutes: 30)), '30m');
      expect(fmtDuration(const Duration(minutes: -5)), '0m');
    });

    test('period label', () {
      expect(periodLabel('2026-07'), 'Jul');
    });
  });
}
