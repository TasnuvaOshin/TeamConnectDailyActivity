import 'package:shared_preferences/shared_preferences.dart';

import '../models/attendance.dart';

/// STATIC / FRONTEND-ONLY: the third-party API has no attendance endpoints,
/// so GPS check-in/check-out is stored locally on the device
/// (shared_preferences, one record per calendar day).
class LocalAttendanceStore {
  String _key(DateTime day) =>
      'tc_att_${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  Future<Attendance?> forDay(String userId, DateTime day) async {
    final p = await SharedPreferences.getInstance();
    final inIso = p.getString('${_key(day)}_in');
    if (inIso == null) return null;
    final outIso = p.getString('${_key(day)}_out');
    return Attendance(
      id: _key(day),
      userId: userId,
      date: DateTime(day.year, day.month, day.day),
      checkIn: DateTime.tryParse(inIso),
      checkOut: outIso != null ? DateTime.tryParse(outIso) : null,
      note: p.getString('${_key(day)}_note'),
    );
  }

  Future<void> checkIn(DateTime day, {String? note}) async {
    final p = await SharedPreferences.getInstance();
    if (p.getString('${_key(day)}_in') != null) return; // already checked in
    await p.setString('${_key(day)}_in', DateTime.now().toIso8601String());
    if (note != null) await p.setString('${_key(day)}_note', note);
  }

  Future<void> checkOut(DateTime day, {String? note}) async {
    final p = await SharedPreferences.getInstance();
    if (p.getString('${_key(day)}_in') == null) return;
    if (p.getString('${_key(day)}_out') != null) return; // already closed
    await p.setString('${_key(day)}_out', DateTime.now().toIso8601String());
    if (note != null) await p.setString('${_key(day)}_note', note);
  }
}
