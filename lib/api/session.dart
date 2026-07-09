import 'package:shared_preferences/shared_preferences.dart';

import 'api_models.dart';

/// Persisted session for the signed-in user (per the guide's
/// "Updating Session Data" pattern). `isDemo` marks offline demo profiles
/// that never touch the API.
class Session {
  final String userId; // server row id (used in API calls)
  final String empId;
  final String name;
  final String designation;
  final String location;
  final String team;
  final String portfolio;
  final bool isDemo;

  const Session({
    required this.userId,
    required this.empId,
    required this.name,
    required this.designation,
    required this.location,
    required this.team,
    required this.portfolio,
    this.isDemo = false,
  });

  factory Session.fromProfileDatum(ProfileDatum d) => Session(
        userId: d.id,
        empId: d.empId,
        name: d.empName,
        designation: d.empDesignation,
        location: d.location,
        team: d.team,
        portfolio: d.portfolio,
      );
}

class SessionStore {
  static const _keys = (
    userId: 'tc_userid',
    empId: 'tc_empid',
    name: 'tc_name',
    designation: 'tc_designation',
    location: 'tc_location',
    team: 'tc_team',
    portfolio: 'tc_portfolio',
    isDemo: 'tc_is_demo',
  );

  Future<Session?> load() async {
    final p = await SharedPreferences.getInstance();
    final userId = p.getString(_keys.userId);
    if (userId == null || userId.isEmpty) return null;
    return Session(
      userId: userId,
      empId: p.getString(_keys.empId) ?? '',
      name: p.getString(_keys.name) ?? '',
      designation: p.getString(_keys.designation) ?? '',
      location: p.getString(_keys.location) ?? '',
      team: p.getString(_keys.team) ?? '',
      portfolio: p.getString(_keys.portfolio) ?? '',
      isDemo: p.getBool(_keys.isDemo) ?? false,
    );
  }

  Future<void> save(Session s) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_keys.userId, s.userId);
    await p.setString(_keys.empId, s.empId);
    await p.setString(_keys.name, s.name);
    await p.setString(_keys.designation, s.designation);
    await p.setString(_keys.location, s.location);
    await p.setString(_keys.team, s.team);
    await p.setString(_keys.portfolio, s.portfolio);
    await p.setBool(_keys.isDemo, s.isDemo);
  }

  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_keys.userId);
    await p.remove(_keys.empId);
    await p.remove(_keys.name);
    await p.remove(_keys.designation);
    await p.remove(_keys.location);
    await p.remove(_keys.team);
    await p.remove(_keys.portfolio);
    await p.remove(_keys.isDemo);
  }
}
