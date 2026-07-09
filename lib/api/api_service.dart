import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_models.dart';
import 'app_base.dart';

/// Thin request wrapper for the third-party ACI panel API.
/// Builds `baseUrl + path`, sends the request, returns a parsed model.
/// The base URL is refreshed at runtime from `update/update.php` and
/// persisted so the app keeps working across restarts.
class ApiService {
  String _baseUrl;
  ApiService([String? baseUrl]) : _baseUrl = baseUrl ?? AppBase.defaultBaseUrl;

  String get baseUrl => _baseUrl;

  static const _baseUrlKey = 'tc_baseurl';

  /// Load the persisted base URL, then try to refresh it from the server
  /// (POST update/update.php per the guide's `getBaseUrl()` flow).
  /// Failures are non-fatal — the app falls back to the stored/default URL.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_baseUrlKey) ?? AppBase.defaultBaseUrl;
    try {
      final response = await http
          .post(Uri.parse('$_baseUrl${AppBase.updateEndPoint}'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final update = updateModelFromJson(response.body);
        if (update.baseurl.isNotEmpty) {
          _baseUrl = update.baseurl;
          await prefs.setString(_baseUrlKey, _baseUrl);
        }
      }
    } catch (_) {
      // Offline or endpoint unreachable — keep the current base URL.
    }
  }

  Future<T> get<T>({
    required String path,
    required T Function(String body) parser,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final response =
        await http.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('Request failed: ${response.statusCode}');
    }
    return parser(response.body);
  }

  Future<T> post<T>({
    required String path,
    required Map<String, dynamic> body,
    required T Function(String body) parser,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final response = await http
        .post(uri,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('Request failed: ${response.statusCode}');
    }
    return parser(response.body);
  }

  /* ───────── Typed endpoint helpers ───────── */

  String _q(String v) => Uri.encodeComponent(v);

  /// GET auth/login2.php?id={staffId}&password={password}
  Future<ProfileModel> login(String staffId, String password) => get(
        path:
            '${AppBase.loginEndPoint}?id=${_q(staffId)}&password=${_q(password)}',
        parser: profileModelFromJson,
      );

  /// GET activity/activity.php?id=&type=&details=&lat=&lan=
  Future<DefaultModel> submitActivity({
    required String userId,
    required String typeCode,
    required String details,
    String? lat,
    String? lan,
  }) =>
      get(
        path: '${AppBase.submitActivityEndPoint}?id=${_q(userId)}'
            '&type=${_q(typeCode)}&details=${_q(details)}'
            '&lat=${_q(lat ?? '')}&lan=${_q(lan ?? '')}',
        parser: defaultModelFromJson,
      );

  /// GET activity/get.php?id=&type={type}&all=0
  Future<List<ActivityDetailModel>> fetchActivities({
    required String userId,
    String type = '',
  }) =>
      get(
        path:
            '${AppBase.activityListEndPoint}?id=${_q(userId)}&type=${_q(type)}&all=0',
        parser: activityDetailModelFromJson,
      );

  /// GET task/get.php?id=
  Future<List<TaskModel>> fetchTasks(String userId) => get(
        path: '${AppBase.taskListEndPoint}?id=${_q(userId)}',
        parser: taskModelFromJson,
      );

  /// GET task/complete.php?id=&date=
  Future<List<TaskModel>> fetchCompletedTasks(String userId, String date) =>
      get(
        path:
            '${AppBase.taskCompleteListEndPoint}?id=${_q(userId)}&date=${_q(date)}',
        parser: taskModelFromJson,
      );

  /// GET task/add2.php?... — creates a task for the signed-in user
  /// (the API has no cross-user assignment).
  Future<DefaultModel> addTask({
    required String userId,
    required String worktype,
    required String details,
    String remarks = '',
    String starttime = '',
    String isAgenda = '0',
    String selectedAgenda = '',
    String selectedTerritory = '',
    String? postedDate,
    String? lat,
    String? lan,
  }) =>
      get(
        path: '${AppBase.taskAddEndPoint}?id=${_q(userId)}'
            '&worktype=${_q(worktype)}&details=${_q(details)}'
            '&remarks=${_q(remarks)}&starttime=${_q(starttime)}'
            '&is_agenda=${_q(isAgenda)}&selected_agenda=${_q(selectedAgenda)}'
            '&selected_territory=${_q(selectedTerritory)}'
            '&posteddate=${_q(postedDate ?? DateTime.now().toIso8601String().substring(0, 10))}'
            '&lat=${_q(lat ?? '')}&lan=${_q(lan ?? '')}',
        parser: defaultModelFromJson,
      );

  /// GET task/update2.php?taskid=&type=&visited_territory=&vlat=&vlan=
  /// ⚠ ASSUMPTION: `type='1'` marks the task done (legacy semantics —
  /// verify against the server).
  Future<DefaultModel> updateTask({
    required String taskId,
    String type = '1',
    String visitedTerritory = '',
    String? lat,
    String? lan,
  }) =>
      get(
        path: '${AppBase.taskUpdateEndPoint}?taskid=${_q(taskId)}'
            '&type=${_q(type)}&visited_territory=${_q(visitedTerritory)}'
            '&vlat=${_q(lat ?? '')}&vlan=${_q(lan ?? '')}',
        parser: defaultModelFromJson,
      );

  /// GET task/update_details.php?taskid=&details=
  Future<DefaultModel> updateTaskDetails(String taskId, String details) => get(
        path:
            '${AppBase.taskUpdateDetailsEndPoint}?taskid=${_q(taskId)}&details=${_q(details)}',
        parser: defaultModelFromJson,
      );

  /// GET task/get_territory.php
  Future<List<TerritoryModel>> fetchTerritories() => get(
        path: AppBase.territoryListEndPoint,
        parser: territoryModelFromJson,
      );

  /// GET auth/register2.php?id={staff_id}&name={name}&designation={designation}&team={team}&portfolio={portfolio}&sup_id={sup_id}&password={password}
  Future<DefaultModel> register({
    required String staffId,
    required String name,
    required String designation,
    required String team,
    required String portfolio,
    required String supId,
    required String password,
  }) =>
      get(
        path: '${AppBase.registerEndPoint}?id=${_q(staffId)}&name=${_q(name)}'
            '&designation=${_q(designation)}&team=${_q(team)}'
            '&portfolio=${_q(portfolio)}&sup_id=${_q(supId)}&password=${_q(password)}',
        parser: defaultModelFromJson,
      );

  /// GET task/get_tour.php?id={user_id}
  Future<List<TourModel>> fetchTours(String userId) => get(
        path: '${AppBase.tourListEndPoint}?id=${_q(userId)}',
        parser: tourModelFromJson,
      );

  /// GET update/notification.php?id={user_id}&nkey={nkey}
  Future<DefaultModel> registerNotification(String userId, String nkey) => get(
        path: '${AppBase.notificationEndPoint}?id=${_q(userId)}&nkey=${_q(nkey)}',
        parser: defaultModelFromJson,
      );

  /// GET update/profile.php?id={emp_id}&designation={designation}&password={password}&portfolio={portfolio}&team={team}
  Future<DefaultModel> updateProfile({
    required String empId,
    required String designation,
    required String password,
    required String portfolio,
    required String team,
  }) =>
      get(
        path: '${AppBase.profileUpdateEndPoint}?id=${_q(empId)}'
            '&designation=${_q(designation)}&password=${_q(password)}'
            '&portfolio=${_q(portfolio)}&team=${_q(team)}',
        parser: defaultModelFromJson,
      );

  /// GET update/delete.php?id={user_id}&name={name}
  Future<DefaultModel> deleteAccount(String userId, String name) => get(
        path: '${AppBase.deleteUserEndPoint}?id=${_q(userId)}&name=${_q(name)}',
        parser: defaultModelFromJson,
      );

  /// GET agenda/get.php?id={user_id}
  Future<List<AgendaModel>> fetchAgendas(String userId) => get(
        path: '${AppBase.agendaListEndPoint}?id=${_q(userId)}',
        parser: agendaModelFromJson,
      );

  /// GET agenda/add.php?id={user_id}&agenda={agenda}&lat={lat}&lan={lan}
  Future<DefaultModel> addAgenda({
    required String userId,
    required String agenda,
    String lat = '',
    String lan = '',
  }) =>
      get(
        path: '${AppBase.agendaAddEndPoint}?id=${_q(userId)}'
            '&agenda=${_q(agenda)}&lat=${_q(lat)}&lan=${_q(lan)}',
        parser: defaultModelFromJson,
      );

  /// GET agenda/add_new.php?id={user_id}&agenda={agenda}&year={year}&month={month}&lat={lat}&lan={lan}
  Future<DefaultModel> addAgendaNew({
    required String userId,
    required String agenda,
    required String year,
    required String month,
    String lat = '',
    String lan = '',
  }) =>
      get(
        path: '${AppBase.agendaAddNewEndPoint}?id=${_q(userId)}'
            '&agenda=${_q(agenda)}&year=${_q(year)}&month=${_q(month)}&lat=${_q(lat)}&lan=${_q(lan)}',
        parser: defaultModelFromJson,
      );

  /// GET agenda/add_list.php?id={user_id}&agenda={agenda}&lat={lat}&lan={lan}
  Future<DefaultModel> addAgendaList({
    required String userId,
    required String agenda,
    String lat = '',
    String lan = '',
  }) =>
      get(
        path: '${AppBase.agendaAddListEndPoint}?id=${_q(userId)}'
            '&agenda=${_q(agenda)}&lat=${_q(lat)}&lan=${_q(lan)}',
        parser: defaultModelFromJson,
      );
}
