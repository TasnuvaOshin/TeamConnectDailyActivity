import 'dart:convert';

/// Response models for the third-party ACI panel API
/// (shapes per API_IMPLEMENTATION_GUIDE.md).

/// Shared success/fail envelope: `{"response":"200","data":...}`.
class DefaultModel {
  final String response;
  final dynamic data;
  DefaultModel({required this.response, this.data});

  bool get ok => response == '200';

  factory DefaultModel.fromJson(Map<String, dynamic> m) => DefaultModel(
        response: '${m['response'] ?? ''}',
        data: m['data'],
      );
}

DefaultModel defaultModelFromJson(String body) {
  if (body.trim().isEmpty) return DefaultModel(response: '400');
  return DefaultModel.fromJson(json.decode(body) as Map<String, dynamic>);
}

/// Login response — `data` is a list of employee records (or a raw string
/// in edge cases).
class ProfileModel {
  final String response;
  final List<ProfileDatum> data;
  ProfileModel({required this.response, required this.data});

  bool get ok => response == '200' && data.isNotEmpty;

  factory ProfileModel.fromJson(Map<String, dynamic> m) {
    final raw = m['data'];
    return ProfileModel(
      response: '${m['response'] ?? ''}',
      data: raw is List
          ? raw
              .whereType<Map<String, dynamic>>()
              .map(ProfileDatum.fromJson)
              .toList()
          : const [],
    );
  }
}

class ProfileDatum {
  final String id;
  final String empId;
  final String empName;
  final String empDesignation;
  final String location;
  final String team;
  final String portfolio;

  ProfileDatum({
    required this.id,
    required this.empId,
    required this.empName,
    required this.empDesignation,
    required this.location,
    required this.team,
    required this.portfolio,
  });

  factory ProfileDatum.fromJson(Map<String, dynamic> m) => ProfileDatum(
        id: '${m['id'] ?? ''}',
        empId: '${m['emp_id'] ?? ''}',
        empName: '${m['emp_name'] ?? ''}',
        empDesignation: '${m['emp_designation'] ?? ''}',
        location: '${m['location'] ?? ''}',
        team: '${m['team'] ?? ''}',
        portfolio: '${m['portfolio'] ?? ''}',
      );
}

ProfileModel profileModelFromJson(String body) {
  if (body.trim().isEmpty) return ProfileModel(response: '400', data: const []);
  return ProfileModel.fromJson(json.decode(body) as Map<String, dynamic>);
}

/// One row from `activity/get.php`.
class ActivityDetailModel {
  final String id;
  final String details;
  final String date; // yyyy-MM-dd
  final String time; // HH:mm
  final String type; // numeric code
  final String userid;

  ActivityDetailModel({
    required this.id,
    required this.details,
    required this.date,
    required this.time,
    required this.type,
    required this.userid,
  });

  factory ActivityDetailModel.fromJson(Map<String, dynamic> m) =>
      ActivityDetailModel(
        id: '${m['id'] ?? ''}',
        details: '${m['details'] ?? ''}',
        date: '${m['date'] ?? ''}',
        time: '${m['time'] ?? ''}',
        type: '${m['type'] ?? ''}',
        userid: '${m['userid'] ?? ''}',
      );
}

List<ActivityDetailModel> activityDetailModelFromJson(String body) {
  if (body.trim().isEmpty) return const [];
  final decoded = json.decode(body);
  final list = decoded is List
      ? decoded
      : decoded is Map<String, dynamic> && decoded['data'] is List
          ? decoded['data'] as List
          : const [];
  return list
      .whereType<Map<String, dynamic>>()
      .map(ActivityDetailModel.fromJson)
      .toList();
}

/// One row from `task/get.php` / `task/complete.php`.
class TaskModel {
  final String id;
  final String details;
  final String remarks;
  final String worktype;
  final String date;
  final String time;
  final String status;
  final String starttime;
  final String userid;
  final String done; // "0"/"1"
  final String? doneDate;
  final String? doneTime;
  final String pending;
  final String isAgenda;
  final String? selectedTerritory;
  final String? visitedTerritory;

  TaskModel({
    required this.id,
    required this.details,
    required this.remarks,
    required this.worktype,
    required this.date,
    required this.time,
    required this.status,
    required this.starttime,
    required this.userid,
    required this.done,
    required this.pending,
    required this.isAgenda,
    this.doneDate,
    this.doneTime,
    this.selectedTerritory,
    this.visitedTerritory,
  });

  bool get isDone => done == '1' || status.toLowerCase() == 'done';

  factory TaskModel.fromJson(Map<String, dynamic> m) => TaskModel(
        id: '${m['id'] ?? ''}',
        details: '${m['details'] ?? ''}',
        remarks: '${m['remarks'] ?? ''}',
        worktype: '${m['worktype'] ?? ''}',
        date: '${m['date'] ?? ''}',
        time: '${m['time'] ?? ''}',
        status: '${m['status'] ?? ''}',
        starttime: '${m['starttime'] ?? ''}',
        userid: '${m['userid'] ?? ''}',
        done: '${m['done'] ?? '0'}',
        pending: '${m['pending'] ?? '0'}',
        isAgenda: '${m['is_agenda'] ?? '0'}',
        doneDate: m['done_date']?.toString(),
        doneTime: m['done_time']?.toString(),
        // Legacy API misspells this field as `seleted_territory`.
        selectedTerritory:
            (m['seleted_territory'] ?? m['selected_territory'])?.toString(),
        visitedTerritory: m['visited_territory']?.toString(),
      );
}

List<TaskModel> taskModelFromJson(String body) {
  if (body.trim().isEmpty) return const [];
  final decoded = json.decode(body);
  final list = decoded is List
      ? decoded
      : decoded is Map<String, dynamic> && decoded['data'] is List
          ? decoded['data'] as List
          : const [];
  return list
      .whereType<Map<String, dynamic>>()
      .map(TaskModel.fromJson)
      .toList();
}

/// Row from `task/get_territory.php`.
class TerritoryModel {
  final String id;
  final String name;
  TerritoryModel({required this.id, required this.name});

  factory TerritoryModel.fromJson(Map<String, dynamic> m) => TerritoryModel(
      id: '${m['id'] ?? ''}', name: '${m['name'] ?? ''}');
}

List<TerritoryModel> territoryModelFromJson(String body) {
  if (body.trim().isEmpty) return const [];
  final decoded = json.decode(body);
  final list = decoded is List
      ? decoded
      : decoded is Map<String, dynamic> && decoded['data'] is List
          ? decoded['data'] as List
          : const [];
  return list
      .whereType<Map<String, dynamic>>()
      .map(TerritoryModel.fromJson)
      .toList();
}

/// Response of `update/update.php` — app metadata + runtime base URL.
class UpdateModel {
  final String id;
  final String version;
  final String link;
  final String baseurl;
  final String delAcc;

  UpdateModel({
    required this.id,
    required this.version,
    required this.link,
    required this.baseurl,
    required this.delAcc,
  });

  factory UpdateModel.fromJson(Map<String, dynamic> m) => UpdateModel(
        id: '${m['id'] ?? ''}',
        version: '${m['version'] ?? ''}',
        link: '${m['link'] ?? ''}',
        baseurl: '${m['baseurl'] ?? ''}',
        delAcc: '${m['del_acc'] ?? '0'}',
      );
}

UpdateModel updateModelFromJson(String body) {
  if (body.trim().isEmpty) {
    return UpdateModel(id: '', version: '', link: '', baseurl: '', delAcc: '0');
  }
  final decoded = json.decode(body);
  if (decoded is List && decoded.isNotEmpty) {
    return UpdateModel.fromJson(decoded.first as Map<String, dynamic>);
  }
  return UpdateModel.fromJson(decoded as Map<String, dynamic>);
}

class TourModel {
  final String id;
  final String details;
  final String remarks;
  final String worktype;
  final String date;
  final String time;
  final String status;
  final String starttime;
  final String userid;
  final String done;
  final String? doneDate;
  final String? doneTime;
  final String pending;
  final String isAgenda;
  final String? selectedAgenda;
  final String? selectedTerritory;
  final String? visitedTerritory;
  final String isTour;

  TourModel({
    required this.id,
    required this.details,
    required this.remarks,
    required this.worktype,
    required this.date,
    required this.time,
    required this.status,
    required this.starttime,
    required this.userid,
    required this.done,
    required this.pending,
    required this.isAgenda,
    this.doneDate,
    this.doneTime,
    this.selectedAgenda,
    this.selectedTerritory,
    this.visitedTerritory,
    required this.isTour,
  });

  bool get isDone => done == '1' || status.toLowerCase() == 'done';

  factory TourModel.fromJson(Map<String, dynamic> m) => TourModel(
        id: '${m['id'] ?? ''}',
        details: '${m['details'] ?? ''}',
        remarks: '${m['remarks'] ?? ''}',
        worktype: '${m['worktype'] ?? ''}',
        date: '${m['date'] ?? ''}',
        time: '${m['time'] ?? ''}',
        status: '${m['status'] ?? ''}',
        starttime: '${m['starttime'] ?? ''}',
        userid: '${m['userid'] ?? ''}',
        done: '${m['done'] ?? '0'}',
        pending: '${m['pending'] ?? '0'}',
        isAgenda: '${m['is_agenda'] ?? '0'}',
        doneDate: m['done_date']?.toString(),
        doneTime: m['done_time']?.toString(),
        selectedAgenda: m['selected_agenda']?.toString(),
        selectedTerritory: (m['seleted_territory'] ?? m['selected_territory'])?.toString(),
        visitedTerritory: m['visited_territory']?.toString(),
        isTour: '${m['is_tour'] ?? '0'}',
      );
}

List<TourModel> tourModelFromJson(String body) {
  if (body.trim().isEmpty) return const [];
  final decoded = json.decode(body);
  final list = decoded is List
      ? decoded
      : decoded is Map<String, dynamic> && decoded['data'] is List
          ? decoded['data'] as List
          : const [];
  return list
      .whereType<Map<String, dynamic>>()
      .map(TourModel.fromJson)
      .toList();
}

class AgendaModel {
  final String id;
  final String userid;
  final String date;
  final String agenda;
  final String month;
  final String year;

  AgendaModel({
    required this.id,
    required this.userid,
    required this.date,
    required this.agenda,
    required this.month,
    required this.year,
  });

  factory AgendaModel.fromJson(Map<String, dynamic> m) => AgendaModel(
        id: '${m['id'] ?? ''}',
        userid: '${m['userid'] ?? ''}',
        date: '${m['date'] ?? ''}',
        agenda: '${m['agenda'] ?? ''}',
        month: '${m['month'] ?? ''}',
        year: '${m['year'] ?? ''}',
      );
}

List<AgendaModel> agendaModelFromJson(String body) {
  if (body.trim().isEmpty) return const [];
  final decoded = json.decode(body);
  final list = decoded is List
      ? decoded
      : decoded is Map<String, dynamic> && decoded['data'] is List
          ? decoded['data'] as List
          : const [];
  return list
      .whereType<Map<String, dynamic>>()
      .map(AgendaModel.fromJson)
      .toList();
}