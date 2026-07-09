/// Central endpoint configuration for the third-party ACI panel API.
/// Pattern per API_IMPLEMENTATION_GUIDE.md: finalUrl = baseUrl + endpointPath.
/// The base URL can be replaced at runtime from `update/update.php`.
class AppBase {
  /// Default base URL that ships with the app.
  static const String defaultBaseUrl = 'https://acipanel.com/activity/';

  // Auth
  static const String loginEndPoint = 'auth/login2.php'; // ?id=&password=
  static const String registerEndPoint = 'auth/register2.php';

  // Activity
  static const String submitActivityEndPoint =
      'activity/activity.php'; // ?id=&type=&details=&lat=&lan=
  static const String activityListEndPoint =
      'activity/get.php'; // ?id=&type=&all=0

  // Tasks
  static const String taskListEndPoint = 'task/get.php'; // ?id=
  static const String taskAddEndPoint = 'task/add2.php';
  static const String taskCompleteListEndPoint =
      'task/complete.php'; // ?id=&date=
  static const String taskUpdateEndPoint =
      'task/update2.php'; // ?taskid=&type=&visited_territory=&vlat=&vlan=
  static const String taskUpdateDetailsEndPoint =
      'task/update_details.php'; // ?taskid=&details=
  static const String tourListEndPoint = 'task/get_tour.php'; // ?id=
  static const String territoryListEndPoint = 'task/get_territory.php';

  // Agenda
  static const String agendaAddEndPoint = 'agenda/add.php';
  static const String agendaAddNewEndPoint = 'agenda/add_new.php';
  static const String agendaAddListEndPoint = 'agenda/add_list.php';
  static const String agendaListEndPoint = 'agenda/get.php'; // ?id=

  // Update / meta
  static const String updateEndPoint = 'update/update.php';
  static const String notificationEndPoint =
      'update/notification.php'; // ?id=&nkey=
  static const String profileUpdateEndPoint = 'update/profile.php';
  static const String deleteUserEndPoint = 'update/delete.php'; // ?id=&name=
}

/// Static mapping between the app's activity category slugs and the numeric
/// `type` codes the third-party API expects.
///
/// ⚠ ASSUMPTION: the legacy API uses opaque numeric type codes; this mapping
/// is a best-guess and lives here so it can be corrected in one place.
const Map<String, String> activityTypeCodes = {
  'market_visit': '1',
  'meeting': '2',
  'sales_call': '3',
  'service_followup': '4',
  'reporting': '5',
  'other': '6',
};

String activityTypeToCode(String slug) => activityTypeCodes[slug] ?? '6';

String activityCodeToType(String? code) {
  for (final e in activityTypeCodes.entries) {
    if (e.value == code) return e.key;
  }
  return 'other';
}