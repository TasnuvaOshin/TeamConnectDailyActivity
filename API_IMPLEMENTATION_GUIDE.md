# API Implementation Guide for Reuse in Flutter

This guide explains the request pattern used by this app so you can copy the same approach into another Flutter project.

## What This App Uses

- A single API service wrapper that prefixes every request with a runtime base URL.
- Mostly `GET` requests, even for operations that change data on the server.
- JSON response parsing through model-specific converter functions.
- Local storage for session data such as user ID, name, team, and base URL.
- Optional geolocation fields for requests that need location validation.

## Core Structure

The current app is organized around these pieces:

- `AppBase` holds the base URL and endpoint paths.
- `ApiService` sends HTTP requests and handles basic response validation.
- `AuthController` calls `ApiService`, parses results, and stores session values.
- Model files expose parser functions such as `profileModelFromJson(...)`.

If you reuse this in another project, keep the same separation:

1. Put the host and endpoint paths in one config file.
2. Put all request logic in one service class.
3. Keep parsing logic in model classes or generated parser functions.
4. Keep UI widgets unaware of raw HTTP details.

## Base URL Pattern

The app builds the final URL like this:

```text
finalUrl = baseUrl + endpointPath
```

In this codebase, `baseUrl` defaults to `https://acipanel.com/activity/`, but it can be overwritten at runtime from the server response.

For reuse in another app, keep the same pattern and replace only the base domain:

```dart
class AppBase {
  static const String baseUrl = 'https://example.com/api/';
  static const String loginEndPoint = 'auth/login2.php?id=';
}
```

## Request Wrapper

The reusable request wrapper should do three things:

- Build the final URI.
- Send the request.
- Return either a parsed model or a standard error message.

Current app behavior:

- `GET` requests are sent with `http.get(...)`.
- `POST` requests are sent with JSON headers and `json.encode(body)`.
- A non-`200` status returns the shared API error message.

Recommended reusable pattern:

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl;

  ApiService(this.baseUrl);

  Future<T> get<T>({
    required String path,
    required T Function(String body) parser,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await http.get(uri);

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
    final uri = Uri.parse('$baseUrl$path');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('Request failed: ${response.statusCode}');
    }

    return parser(response.body);
  }
}
```

## Example: Login Flow

The login request in this app is:

```text
GET /activity/auth/login2.php?id={staff_id}&password={password}
```

Example reusable call:

```dart
final response = await apiService.get(
  path: 'auth/login2.php?id=$staffId&password=${Uri.encodeComponent(password)}',
  parser: profileModelFromJson,
);
```

Expected success response shape:

```json
{
  "response": "200",
  "data": [
    {
      "id": "648",
      "emp_id": "59784",
      "emp_name": "sifat"
    }
  ]
}
```

## Example: Updating Session Data

After login succeeds, the app stores values locally:

- user ID
- employee ID
- name
- designation
- location
- team
- portfolio

In another Flutter project, you can do the same with `GetStorage`, `shared_preferences`, or your own secure storage layer.

Example pattern:

```dart
storage.write('userid', response.data[0].id);
storage.write('name', response.data[0].empName);
storage.write('team', response.data[0].team ?? '');
```

## Handling Query Parameters Safely

Many endpoints accept values directly in the query string. Always URL-encode values that can contain spaces or symbols.

Use:

```dart
Uri.encodeComponent(value)
```

Especially for:

- names
- remarks
- task details
- territory values
- agenda text
- passwords

## Location-Dependent Requests

Some operations in this app require GPS coordinates before sending the API call.

Pattern:

1. Request location permission.
2. Validate that location is available.
3. Read latitude and longitude.
4. Attach them as query parameters.

Example:

```dart
final position = await LocationService.getLocationWithValidation();
if (position == null) {
  return 'Location Required';
}

final lat = position.latitude.toString();
final lan = position.longitude.toString();
```

This is used by activity submission, task submission, agenda submission, and task updates.

## Adding a New Endpoint in Another Project

To reuse the same style for a new endpoint:

1. Add the path constant to `AppBase`.
2. Add a method in `ApiService` only if the HTTP method differs.
3. Add a model parser for the response JSON.
4. Call the service from a controller or repository.
5. Store any returned session data if needed.

Example:

```dart
static const String profileEndPoint = 'user/profile.php?id=';
```

```dart
Future<ProfileModel> fetchProfile(String userId) {
  return apiService.get(
    path: 'user/profile.php?id=$userId',
    parser: profileModelFromJson,
  );
}
```

## Endpoints Used By This App

Default base URL:

`https://acipanel.com/activity/`

Note: the app can replace the base URL at runtime after calling the update endpoint, so all paths below are resolved against the current stored `baseurl` value. The URLs below use the default base URL that ships with the app.

| Method | Full URL | Response model / parser | Used In |
| --- | --- | --- | --- |
| GET | `https://acipanel.com/activity/auth/login2.php?id={staff_id}&password={password}` | `ProfileModel` via `profileModelFromJson(...)` | Login |
| GET | `https://acipanel.com/activity/auth/register2.php?id={staff_id}&name={name}&designation={designation}&team={team}&portfolio={portfolio}&sup_id={sup_id}&password={password}` | `DefaultModel` via `defaultModelFromJson(...)` | Registration |
| GET | `https://acipanel.com/activity/activity/activity.php?id={user_id}&type={type}&details={details}&lat={lat}&lan={lan}` | `DefaultModel` via `defaultModelToJson(...)` in current code | Submit activity |
| GET | `https://acipanel.com/activity/task/add2.php?id={user_id}&worktype={worktype}&details={details}&remarks={remarks}&starttime={starttime}&is_agenda={is_agenda}&selected_agenda={selected_agenda}&selected_territory={selected_territory}&posteddate={posteddate}&lat={lat}&lan={lan}` | `DefaultModel` via `defaultModelToJson(...)` in current code | Submit task |
| GET | `https://acipanel.com/activity/activity/get.php?id={user_id}&type={type}&all=0` | `ActivityDetailModel` via `activityDetailModelFromJson(...)` | Fetch activity list |
| GET | `https://acipanel.com/activity/update/update.php` | `UpdateModel` via `updateModelFromJson(...)` | Update app metadata (`updateApp()`) |
| GET | `https://acipanel.com/activity/update/notification.php?id={user_id}&nkey={nkey}` | `DefaultModel` via `defaultModelFromJson(...)` | Update notification |
| GET | `https://acipanel.com/activity/task/get.php?id={user_id}` | `TaskModel` via `taskModelFromJson(...)` | Fetch task list |
| GET | `https://acipanel.com/activity/task/get_tour.php?id={user_id}` | `TourModel` via `tourModelFromJson(...)` | Fetch tour list |
| GET | `https://acipanel.com/activity/task/get_territory.php` | `TerritoryModel` via `territoryModelFromJson(...)` | Fetch territory list |
| GET | `https://acipanel.com/activity/task/complete.php?id={user_id}&date={date}` | `TaskModel` via `taskModelFromJson(...)` | Fetch completed tasks |
| GET | `https://acipanel.com/activity/task/update_details.php?taskid={task_id}&details={details}` | `DefaultModel` via `defaultModelToJson(...)` in current code | Update task details |
| GET | `https://acipanel.com/activity/task/update2.php?taskid={task_id}&type={type}&visited_territory={visited_territory}&vlat={lat}&vlan={lan}` | `DefaultModel` via `defaultModelFromJson(...)` | Update task |
| GET | `https://acipanel.com/activity/update/delete.php?id={user_id}&name={name}` | `DefaultModel` via `defaultModelToJson(...)` in current code | Delete user |
| GET | `https://acipanel.com/activity/agenda/add.php?id={user_id}&agenda={agenda}&lat={lat}&lan={lan}` | `DefaultModel` via `defaultModelToJson(...)` in current code | Submit monthly agenda |
| GET | `https://acipanel.com/activity/agenda/add_new.php?id={user_id}&agenda={agenda}&year={year}&month={month}&lat={lat}&lan={lan}` | `DefaultModel` via `defaultModelToJson(...)` in current code | Submit monthly agenda (new 24 flow) |
| GET | `https://acipanel.com/activity/agenda/add_list.php?id={user_id}&agenda={agenda}&lat={lat}&lan={lan}` | `DefaultModel` via `defaultModelToJson(...)` in current code | Submit agenda list |
| GET | `https://acipanel.com/activity/agenda/get.php?id={user_id}` | `AgendaModel` via `agendaModelFromJson(...)` | Fetch agenda list |
| GET | `https://acipanel.com/activity/update/profile.php?id={emp_id}&designation={designation}&password={password}&portfolio={portfolio}&team={team}` | `DefaultModel` via `defaultModelFromJson(...)` | Update profile |
| POST | `https://acipanel.com/activity/update/update.php` | `UpdateModel` via `updateModelFromJson(...)` | Fetch base URL in `getBaseUrl()` |

## Notes

- The app uses `GET` for most operations, even when the request changes data on the server.
- Query values should be URL-encoded when they can contain spaces, slashes, or special characters.
- I did not include `AppBase.web*` endpoint constants here because they are defined in the codebase but not referenced by any current app flow.

## Response Models

These are the actual response shapes used by the app. Reuse these same structures when you copy the API layer into another Flutter project.

### ProfileModel

Used by the login endpoint.

```json
{
  "response": "200",
  "data": [
    {
      "id": "648",
      "emp_id": "59784",
      "emp_name": "sifat",
      "emp_designation": "Mobile Application Developer",
      "location": "",
      "team": "Marketing Team",
      "portfolio": "Tractor"
    }
  ]
}
```

Fields:

- `response`: login/status code returned by the server.
- `data`: either a list of employee records or a raw string in edge cases.

Each `Datum` item contains:

- `id`
- `emp_id`
- `emp_name`
- `emp_designation`
- `location`
- `team`
- `portfolio`

### DefaultModel

Used for simple success/fail responses.

```json
{
  "response": "200",
  "data": "..."
}
```

Fields:

- `response`: usually `200` on success.
- `data`: optional string payload.

### ActivityDetailModel

Used by the activity history fetch.

```json
{
  "id": "1",
  "details": "Visited customer",
  "date": "2026-07-08",
  "time": "09:30",
  "type": "1",
  "userid": "59784"
}
```

Fields:

- `id`
- `details`
- `date`
- `time`
- `type`
- `userid`

### TaskModel

Used by task list and completed-task endpoints.

```json
{
  "id": "1",
  "details": "Follow up",
  "remarks": "Done",
  "worktype": "Office Work",
  "date": "2026-07-08",
  "time": "10:00",
  "status": "Pending",
  "starttime": "09:00",
  "userid": "59784",
  "done": "0",
  "done_date": null,
  "done_time": null,
  "pending": "1",
  "pending_date": null,
  "pending_time": null,
  "is_agenda": "0",
  "seleted_territory": "..."
}
```

Fields:

- `id`
- `details`
- `remarks`
- `worktype`
- `date`
- `time`
- `status`
- `starttime`
- `userid`
- `done`
- `done_date`
- `done_time`
- `pending`
- `pending_date`
- `pending_time`
- `is_agenda`
- `seleted_territory`

### TourModel

Used by the tour list endpoint.

```json
{
  "id": "1",
  "details": "Meeting route",
  "remarks": "",
  "worktype": "Field Work",
  "date": "2026-07-08",
  "time": "10:00",
  "status": "Pending",
  "starttime": "09:00",
  "userid": "59784",
  "done": "0",
  "done_date": null,
  "done_time": null,
  "pending": "1",
  "pending_date": null,
  "pending_time": null,
  "is_agenda": "0",
  "selected_agenda": null,
  "seleted_territory": null,
  "visited_territory": null,
  "is_tour": "1"
}
```

Fields:

- `id`
- `details`
- `remarks`
- `worktype`
- `date`
- `time`
- `status`
- `starttime`
- `userid`
- `done`
- `done_date`
- `done_time`
- `pending`
- `pending_date`
- `pending_time`
- `is_agenda`
- `selected_agenda`
- `seleted_territory`
- `visited_territory`
- `is_tour`

### TerritoryModel

Used by the territory lookup endpoint.

```json
{
  "id": "1",
  "name": "Dhaka"
}
```

Fields:

- `id`
- `name`

### AgendaModel

Used by the agenda list endpoint.

```json
{
  "id": "1",
  "userid": "59784",
  "date": "2026-07-08",
  "agenda": "Monthly review",
  "month": "7",
  "year": "2026"
}
```

Fields:

- `id`
- `userid`
- `date`
- `agenda`
- `month`
- `year`

### UpdateModel

Used by the app update metadata endpoint.

```json
{
  "id": "1",
  "version": "1.0.0",
  "link": "https://...",
  "baseurl": "https://acipanel.com/activity/",
  "del_acc": "0"
}
```

Fields:

- `id`
- `version`
- `link`
- `baseurl`
- `del_acc`

## Reuse Checklist

- Replace the base URL in one place.
- Keep endpoint paths centralized.
- Encode query values before sending.
- Use one parsing function per response model.
- Keep request logic out of widgets.
- Store auth/session values in a dedicated persistence layer.
