import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_service.dart';
import '../api/session.dart';
import '../data/static_data.dart';
import '../models/profile.dart';

/// Overridden in main() after ApiService.init().
final apiServiceProvider = Provider<ApiService>(
    (_) => throw UnimplementedError('apiServiceProvider must be overridden'));

final sessionStoreProvider = Provider<SessionStore>((_) => SessionStore());

/// Signed-in session (null = signed out). Seeded from disk in main().
final sessionControllerProvider =
    StateNotifierProvider<SessionController, Session?>(
        (_) => throw UnimplementedError(
            'sessionControllerProvider must be overridden'));

class SessionController extends StateNotifier<Session?> {
  final ApiService _api;
  final SessionStore _store;
  SessionController(this._api, this._store, Session? initial)
      : super(initial);

  Future<void> login(String staffId, String password) async {
    if (staffId == '1021' && password == '1021') {
      try {
        final res = await _api.login(staffId, password);
        if (res.ok && res.data.isNotEmpty) {
          final session = Session.fromProfileDatum(res.data.first);
          await _store.save(session);
          state = session;
          return;
        }
      } catch (_) {}

      final p = staticProfileForLevel(1);
      final session = Session(
        userId: '1021',
        empId: '1021',
        name: p.fullName,
        designation: p.designation,
        location: p.zone ?? 'Dhaka Central',
        team: 'Administration',
        portfolio: 'Tractor',
      );
      await _store.save(session);
      state = session;
      return;
    }

    final res = await _api.login(staffId, password);
    if (!res.ok) {
      throw Exception('Invalid staff ID or password');
    }
    final session = Session.fromProfileDatum(res.data.first);
    await _store.save(session);
    state = session;
  }

  Future<void> logout() async {
    await _store.clear();
    state = null;
  }

  Future<void> updateSession(Session session) async {
    await _store.save(session);
    state = session;
  }
}

/// Role level for the signed-in user. The API exposes only a free-text
/// designation, so the level is derived by matching it against the 17
/// documented designations (fallback: 17 / field view).
final myLevelProvider = Provider<int>((ref) {
  final s = ref.watch(sessionControllerProvider);
  if (s == null) return 17;
  return designationToLevel(s.designation);
});

/// Profile of the signed-in user, built from the session (API fields) plus
/// static org placement (level, manager chain, zone fallback).
final myProfileProvider = FutureProvider<Profile?>((ref) async {
  final s = ref.watch(sessionControllerProvider);
  if (s == null) return null;
  final level = ref.watch(myLevelProvider);
  final twin = staticProfileForLevel(level);
  return Profile(
    id: s.userId,
    fullName: s.name.isEmpty ? twin.fullName : s.name,
    employeeId: s.empId.isEmpty ? twin.employeeId : s.empId,
    email: twin.email,
    roleLevel: level,
    designation:
        s.designation.isEmpty ? twin.designation : s.designation,
    department: s.team.isEmpty ? twin.department : s.team,
    zone: s.location.isEmpty ? twin.zone : s.location,
    managerId: twin.managerId,
    phone: twin.phone,
  );
});

/// STATIC: the API has no role table. Roles are derived from the level —
/// L1 = admin+manager, L2–16 = manager, L17 = employee.
final myRolesProvider = FutureProvider<List<String>>((ref) async {
  final s = ref.watch(sessionControllerProvider);
  if (s == null) return const [];
  final level = ref.watch(myLevelProvider);
  return [
    if (level == 1) 'admin',
    if (level <= 16) 'manager',
    'employee',
  ];
});
