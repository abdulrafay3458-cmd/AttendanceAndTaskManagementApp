import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:attendance_app/main.dart';
import 'package:attendance_app/models/AttendanceRecord.dart';
import 'package:attendance_app/models/HolidaysModel.dart';
import 'package:attendance_app/models/Priority.dart';
import 'package:attendance_app/models/WorkingDay.dart';
import 'package:attendance_app/models/UserDevices.dart';
import 'package:attendance_app/models/apiresponseleave.dart';
import 'package:attendance_app/models/applyimage.dart';
import 'package:attendance_app/models/approvepic.dart';
import 'package:attendance_app/models/chart.dart';
import 'package:attendance_app/models/dayWise.dart';
import 'package:attendance_app/models/employee.dart';
import 'package:attendance_app/models/employeeprofilemodel.dart';
import 'package:attendance_app/models/extra_task_report.dart';
import 'package:attendance_app/models/overtimeresponse.dart';
import 'package:attendance_app/models/pendingTasks.dart';
import 'package:attendance_app/models/prevDateData.dart';
import 'package:attendance_app/models/standardHourGroup.dart';
import 'package:attendance_app/services/ApiClient.dart';
import 'package:attendance_app/services/DeviceInfoProvider.dart';
import 'package:attendance_app/services/leaverequestmodel.dart';
import 'package:attendance_app/services/taskmodel.dart';
import 'package:attendance_app/models/designation.dart';
import 'package:attendance_app/models/leave_type.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:attendance_app/services/teammember.dart';
import 'package:attendance_app/models/task_export_request.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';

class ApiService {
  static String? _authToken;
  static String? get authToken => _authToken;
  static String? _deviceHash;
  static String? get deviceHash => _deviceHash;
  static String? _employeeId;
  static String? get employeeId => _employeeId;
  static Employee? _currentEmployee;
  static Employee? get currentEmployee => _currentEmployee;
  static bool _isFirstTimeLogin = false;
  static bool get isFirstTimeLogin => _isFirstTimeLogin;
  static String? _refreshToken;
  static String? get refreshToken => _refreshToken;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('auth_token');
    _refreshToken = prefs.getString('refresh_token');
    _employeeId = prefs.getString('employee_id');
    // _currentEmployee =   await ApiService.getEmployeeById(employeeId);
    final deviceInfo = await DeviceInfoProvider.getDeviceInfo();
    _deviceHash = await DeviceInfoProvider.generateDeviceHash(deviceInfo);
  }

  static Future<void> saveCredentials(String token, String? employeeId, String? refreshtoken) async {
    _authToken = token;
    _employeeId = employeeId;
    _refreshToken = refreshtoken;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setString('refresh_token', refreshtoken ?? '');
    await prefs.setString('employee_id', employeeId ?? '');
  }

  static Future<void> clearCredentials() async {
    _authToken = null;
    _employeeId = null;
    _currentEmployee = null;
    _refreshToken = null; 
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('employee_id');
    await prefs.remove('refresh_token');
  }

  static Map<String, String> getHeaders() {
    return {
      'Content-Type': 'application/json',
      if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      if (_deviceHash != null) 'device_Hash': '$_deviceHash',
    };
  }

  static Map<String, String> getRefreshToken() {
    return {
      'Content-Type': 'application/json',
      if (_refreshToken != null) 'refreshtoken': '$_refreshToken'
    };
  }

  //  static Future<void> uploadProfileImage({
  //     required File file,
  //     required String name,
  //     required String personId,
  //   }) async {
  //     var request = http.MultipartRequest(
  //       'POST',
  //       Uri.parse('$API_BASE_URL/FaceRecognition/register'),
  //     );

  //     request.fields['name'] = name;
  //     request.fields['personId'] = personId;

  //     request.files.add(
  //       await http.MultipartFile.fromPath(
  //         'photo',
  //         file.path,
  //       ),
  //     );

  //     var response = await request.send();

  //     if (response.statusCode != 200) {
  //       throw Exception('Image upload failed');
  //     }
  //   }

  static Future<bool> markManualCheckIn(
    String? employeeCode,
    DateTime date,
    DateTime checkInTime,
  ) async {
    final response = await http.post(
      Uri.parse('$API_BASE_URL/Attendance/manual-checkin'),
      headers: getHeaders(),
      body: jsonEncode({
        "employeeCode": employeeCode,
        "date": date.toIso8601String(),
        "time": checkInTime.toIso8601String(),
      }),
    );

    return response.statusCode == 200;
  }
// In apiservice.dart
static Future<Map<String, dynamic>> addOvertime({
  required String userTaskId,
  required DateTime overtimeDate,
  required double overtimeHours,
  String? reason,
}) async {
  try {
    final response = await ApiClient().dio.post(
      '/TaskOvertime/add',
      data: {
        'userTaskId': userTaskId,
        'overtimeDate': overtimeDate.toIso8601String(),
        'overtimeHours': overtimeHours,
        'reason': reason,
      },
    );

    final data = response.data;

    if (data is Map && data['success'] == true) {
      return {
        'success': true,
        'overtime': data['overtime'],
        'message': data['message'],
      };
    }

    return {
      'success': false,
      'error': data is Map
          ? (data['message'] ?? data['error'] ?? 'Failed to add overtime')
          : 'Failed to add overtime',
    };
  } on DioException catch (e) {
    final responseData = e.response?.data;

    String message = 'Failed to add overtime';

    if (responseData is Map) {
      message = (responseData['message'] ??
              responseData['error'] ??
              'Failed to add overtime')
          .toString();
    } else if (e.message != null) {
      message = e.message!;
    }

    return {
      'success': false,
      'error': message,
    };
  } catch (e) {
    return {
      'success': false,
      'error': e.toString(),
    };
  }
}

  static Future<bool> markManualCheckOut(
    String? employeeCode,
    DateTime date,
    DateTime checkOutTime,
  ) async {
    final response = await http.post(
      Uri.parse('$API_BASE_URL/Attendance/manual-checkout'),
      headers: getHeaders(),
      body: jsonEncode({
        "employeeCode": employeeCode,
        "date": date.toIso8601String(),
        "time": checkOutTime.toIso8601String(),
      }),
    );

    return response.statusCode == 200;
  }

  static Future<List<WorkingDay>> fetchWorkingDays(String? employeeCode) async {
    // final response = await http.get(
    //   Uri.parse('$API_BASE_URL/employee/employeeWorkingDays/$employeeCode'),
    //   headers: getHeaders(),
    // );

    final response = await ApiClient().dio.get(
      'employee/employeeWorkingDays/$employeeCode',
    );

    if (response.statusCode == 200) {
      List data = response.data;

      return data.map((e) => WorkingDay.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load working days');
    }
  }

  static Future<bool> saveHoliday({
    required DateTime holidayDate,
    required String title,
  }) async {
    try {
      // final response = await http.post(
      //   Uri.parse('$API_BASE_URL/Holiday/Save'),
      //   headers: getHeaders(),
      //   body: jsonEncode({
      //     "date": holidayDate.toIso8601String(),
      //     "title": title,
      //   }),
      // );

      final response = await ApiClient().dio.post(
        'Holiday/Save',
        data: {"date": holidayDate.toIso8601String(), "title": title},
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print("Save Holiday Error: $e");
      return false;
    }
  }

  static Future<bool> editHoliday({
    required DateTime holidayDate,
    required String title,
  }) async {
    try {
      // final response = await http.post(
      //   Uri.parse('$API_BASE_URL/Holiday/Update'),
      //   headers: getHeaders(),
      //   body: jsonEncode({
      //     "date": holidayDate.toIso8601String(),
      //     "title": title,
      //   }),
      // );

      final response = await ApiClient().dio.post(
        'Holiday/Update',
        data: {"date": holidayDate.toIso8601String(), "title": title},
      );

      if (response.statusCode == 200) return true;
      return false;
    } catch (e) {
      print("Edit Holiday Error: $e");
      return false;
    }
  }

  static Future<bool> uploadProfileImage({
    required File file,
    required String name,
    required String personId,
  }) async {
    try {
      // final request = http.MultipartRequest(
      //   'POST',
      //   Uri.parse('$API_BASE_URL/RegistrationImage/apply'),
      //   // Uri.parse('$API_BASE_URL/FaceRecognition/register'),
      // );
      // request.headers.addAll(getHeaders());
      // request.fields['name'] = name;
      // request.fields['personId'] = personId;

      // request.files.add(await http.MultipartFile.fromPath('photo', file.path));

      // final streamedResponse = await request.send();

      final formData = FormData.fromMap({
        'name': name,
        'personId': personId,
        'photo': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
        ),
      });

      final response = await ApiClient().dio.post(
        '/RegistrationImage/apply',
        data: formData,
      );

      if (response.statusCode != 200) {
        return false;
      }

      // READ IMAGE BYTES AND UPDATE MEMORY
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);

      _currentEmployee = currentEmployee!.copyWith(
        faceImageBase64: base64Image,
      );
      return true;
    } catch (e) {
      print('Upload ProfileImage error: $e');
      return false;
    }
  }

  static Future<List<PendingTask>> fetchPendingTasks(String? userId) async {
    final today = DateTime.now();
    final formattedDate =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    // final response = await http.get(
    //   Uri.parse('$API_BASE_URL/Task/GetPendingTasks?userId=$userId'),
    //   headers: getHeaders(),
    // );

    final response = await ApiClient().dio.get(
      'Task/GetPendingTasks?userId=$userId',
    );

    if (response.statusCode == 200) {
      final List data = response.data;
      return data.map((json) => PendingTask.fromJson(json)).toList();
    } else {
      throw Exception("Failed to fetch tasks");
    }
  }

  static Future<List<Holiday>> getHolidays() async {
    // final response = await http.get(
    //   Uri.parse('$API_BASE_URL/Holiday/GetHolidays'),
    //   headers: {"Content-Type": "application/json"},
    // );

    final response = await ApiClient().dio.get('Holiday/GetHolidays');

    final decoded = response.data;

    if (response.statusCode == 200 && decoded['success'] == true) {
      final List list = decoded['holidays'];
      return list.map((e) => Holiday.fromJson(e)).toList();
    } else {
      throw Exception(decoded['message'] ?? "Failed to load holidays");
    }
  }

  // Late & Working Hour
  static Future<Daywise> standardHour(String empCode, DateTime date) async {
    try {
      String dateString = Uri.encodeComponent(date.toIso8601String());
      // final resp = await http.get(
      //   Uri.parse(
      //     '$API_BASE_URL/attendance/daywiseStdHrs?empCode=$empCode&dateTime=$dateString',
      //   ),
      //   headers: getHeaders(),
      // );

      final response = await ApiClient().dio.get(
        'attendance/daywiseStdHrs?empCode=$empCode&dateTime=$dateString',
      );

      if (response.statusCode == 200) {
        final data = response.data;
        return Daywise.fromJson(data);
      } else if (response.statusCode == 404) {
        return Daywise(
          StandardHours: '',
          OverTime: '',
          WorkingHours: '',
          IsLate: false,
        );
      } else {
        final errorResponse = response.data;
        throw Exception(
          'Failed to load data: ${errorResponse['error'] ?? response.statusCode}',
        );
      }
    } catch (e) {
      print('Error in getStandardHour: $e');
      throw Exception('Failed to load data: $e');
    }
  }

  // Previous Date Data
  static Future<PreviousDateData> getDataForDate(
    String date,
    String empId,
  ) async {
    try {
      // final response = await http.get(
      //   Uri.parse(
      //     '$API_BASE_URL/employee/dailyRecord?employeeId=$empId&date=$date',
      //   ),
      //   headers: getHeaders(),
      // );

      final response = await ApiClient().dio.get(
        'employee/dailyRecord?employeeId=$empId&date=$date',
      );

      if (response.statusCode == 200) {
        final jsonData = response.data;

        return PreviousDateData.fromJson(jsonData);
        //  if (jsonData.TaskList is List) {
        //   return jsonData
        //       .map((item) => PreviousDateData.fromJson(item))
        //       .toList();
        // }

        // else if (jsonData is Map<String, dynamic>) {
        //   return [PreviousDateData.fromJson(jsonData)];
        // }

        // return [];
      } else if (response.statusCode == 404) {
        return PreviousDateData(
          checkIn: null,
          checkOut: null,
          isLeave: false,
          taskList: [],
        );
      } else {
        final errorResponse = response.data;
        throw Exception(
          'Failed to load data: ${errorResponse['error'] ?? response.statusCode}',
        );
      }
    } catch (e) {
      print('Error in getDataForDate: $e');
      throw Exception('Failed to load data: $e');
    }
  }

  //Task Summary
  static Future<TaskSummaryResponse?> taskSummary() async {
    try {
      // final response = await http
      //     .get(
      //       Uri.parse('$API_BASE_URL/Task/summary?empCode=$_employeeId'),
      //       headers: getHeaders(),
      //     )
      //     .timeout(const Duration(seconds: 30));

      final response = await ApiClient().dio.get(
        'Task/summary?empCode=$_employeeId',
        options: Options(receiveTimeout: const Duration(seconds: 30)),
      );

      if (response.statusCode != 200) {
        return null;
      }

      final Map<String, dynamic> body = response.data;

      print('Task Summary Response: $body');

      return TaskSummaryResponse(
        ToDoCount: body['toDoCount'] ?? 0,
        InProgressCount: body['inProgressCount'] ?? 0,
        CompleteCount: body['completeCount'] ?? 0,
      );
    } catch (e) {
      print(' taskSummary error: $e');
      return null;
    }
  }

  static Future<bool> getImageApprovalStatus(String employeeId) async {
    try {
      // final response = await http.get(
      //   Uri.parse('$API_BASE_URL/employee/$employeeId/image-status'),
      //   headers: getHeaders(),
      // );

      final response = await ApiClient().dio.get(
        'employee/$employeeId/image-status',
      );

      if (response.statusCode == 200) {
        final data = response.data;
        return data['imageApproved'] ?? false;
      } else {
        print('Failed to fetch image status: ${response.data}');
        return false;
      }
    } catch (e) {
      print('Error checking image approval: $e');
      return false;
    }
  }

  static Future<bool> verifyopt(
    String? _usernameController,
    String? _emailController,
    String? _otp,
  ) async {
    try {
      _otp = "test";
      // final response = await http.post(
      //   Uri.parse("$API_BASE_URL/identity/verifyopt"), // match your route
      //   headers: {"Content-Type": "application/json"},
      //   body: jsonEncode({
      //     "userId": _usernameController,
      //     "email": _emailController,
      //     "oTP": _otp,
      //   }),
      // );

      final response = await ApiClient().dio.post(
        'identity/verifyopt',
        data: {
          "userId": _usernameController,
          "email": _emailController,
          "oTP": _otp,
        },
        options: Options(extra: {'skipAuth': true}),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('Error : $e');
      return false;
    }
  }

  static Future<bool> resetpassword(
    String? _usernameController,
    String? _emailController,
    String? _otp,
  ) async {
    try {
      // final response = await http.post(
      //   Uri.parse("$API_BASE_URL/identity/resetpassword"), // match your route
      //   headers: {"Content-Type": "application/json"},
      //   body: jsonEncode({
      //     "userId": _usernameController,
      //     "email": _emailController,
      //     "oTP": _otp,
      //   }),
      // );

      final response = await ApiClient().dio.post(
        'identity/resetpassword',
        data: {
          "userId": _usernameController,
          "email": _emailController,
          "oTP": _otp,
        },
        options: Options(extra: {'skipAuth': true}),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('Error : $e');
      return false;
    }
  }
  //  static Future<Employee?> getEmployeeById(String? employeeId) async {
  //   final response = await http.get(
  //      Uri.parse('$API_BASE_URL/employee/getEmpCurrentInfo'),
  //      headers: getHeaders(),
  //    );

  //      if (response.statusCode == 200) {
  //        final data = jsonDecode(response.body);
  //          _currentEmployee = Employee.fromJson(data);
  //        return Employee.fromJson(data);
  //      } else if (response.statusCode == 404) {
  //        return null;
  //      } else {
  //        throw Exception('Failed to fetch employee. Status: ${response.statusCode}');
  //      }
  //    }

  static Future<Employee?> getEmployeeById() async {
    // final response = await http.get(
    //   Uri.parse('$API_BASE_URL/employee/getEmpCurrentInfo'),
    //   headers: getHeaders(),
    // );

    final response = await ApiClient().dio.get('employee/getEmpCurrentInfo');

    if (response.statusCode == 200) {
      final data = response.data;
      _currentEmployee = Employee.fromJson(data);
      return Employee.fromJson(data);
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception(
        'Failed to fetch employee. Status: ${response.statusCode}',
      );
    }
  }

  static Future<dynamic> changePassword(
    String oldPassword,
    String newPassword,
  ) async {
    try {
      // final response = await http
      //     .post(
      //       Uri.parse('$API_BASE_URL/identity/change-password'),
      //       headers: getHeaders(),
      //       body: jsonEncode({
      //         'oldPassword': oldPassword,
      //         'newPassword': newPassword,
      //       }),
      //     )
      //     .timeout(Duration(seconds: 20));

      final response = await ApiClient().dio.post(
        'identity/change-password',
        data: {'oldPassword': oldPassword, 'newPassword': newPassword},
        options: Options(receiveTimeout: Duration(seconds: 20)),
      );

      return response.data;
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  Future<void> sendTokenToBackend(String token) async {
    try {
      final response = await ApiClient().dio.post(
        'identity/registerfcmtoken',
        data: {'fcmToken': token},
        options: Options(receiveTimeout: Duration(seconds: 20)),
      );
    } catch (e) {
      print(' Token send failed: $e');
    }
  }

  static Future<List<UserDevices>> fetchAllDevices() async {
    // final response = await http.get(
    //   Uri.parse('$API_BASE_URL/employee/all-registered-devices'),
    //   headers: getHeaders(),
    // );

    final response = await ApiClient().dio.get(
      'employee/all-registered-devices',
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to load devices");
    }

    final List data = response.data;
    return data.map((e) => UserDevices.fromJson(e)).toList();
  }

  static Future<void> removeDevice(String empId) async {
    final url = 'employee/remove-device';
    try {
      final response = await ApiClient().dio.delete(
        url,
        queryParameters: {'empId': empId},
      );

      if (response.statusCode != 200) {
        throw Exception("Failed to remove device");
      }
    } on DioException catch (e) {
      rethrow;
    }
  }

  static Future<bool> requestToRegisterUserDevice() async {
    try {
      final deviceInfo = await DeviceInfoProvider.getDeviceInfo();
      final hash = await DeviceInfoProvider.generateDeviceHash(deviceInfo);
      // final response = await http
      //     .post(
      //       Uri.parse('$API_BASE_URL/employee/requesttoregisteruserdevice'),
      //       headers: getHeaders(),
      //       body: jsonEncode({
      //         'DeviceHash': hash,
      //         'DeviceManufacturer': deviceInfo.manufacturer,
      //         'DeviceModel': deviceInfo.model,
      //       }),
      //     )
      //     .timeout(Duration(seconds: 20));

      final response = await ApiClient().dio.post(
        'employee/requesttoregisteruserdevice',
        data: {
          'DeviceHash': hash,
          'DeviceManufacturer': deviceInfo.manufacturer,
          'DeviceModel': deviceInfo.model,
        },
        options: Options(receiveTimeout: Duration(seconds: 20)),
      );

      // final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> ApproveUserNewDevice(String employeeCode) async {
    try {
      // final response = await http
      //     .post(
      //       Uri.parse('$API_BASE_URL/employee/approveusernewdevice'),
      //       headers: {'Content-Type': 'application/json'},
      //       body: jsonEncode({'employeeCode': employeeCode}),
      //     )
      //     .timeout(Duration(seconds: 20));

      final response = await ApiClient().dio.post(
        'employee/approveusernewdevice',
        data: {'employeeCode': employeeCode},
        options: Options(receiveTimeout: Duration(seconds: 20)),
      );

      final data = response.data;
      if (response.statusCode == 200) {
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

// Login
static Future<Map<String, dynamic>> login(
  String employeeId,
  String password,
) async {
  try {
    print('🔐 Attempting login for: $employeeId');

    final deviceInfo = await DeviceInfoProvider.getDeviceInfo();
    final hash = await DeviceInfoProvider.generateDeviceHash(deviceInfo);
    _isFirstTimeLogin = false;

    final response = await ApiClient().dio.post(
      'identity/login',
      data: {
        'employeeCode': employeeId,
        'password': password,
        'deviceHash': hash,
      },
      options: Options(
        receiveTimeout: const Duration(seconds: 60),
        extra: {'skipAuth': true},
      ),
    );

    print('📡 Login response: ${response.statusCode}');

    final data = response.data;

    if (response.statusCode != 200) {
      print('Login failed (non-200): $data');
      return {
        'success': false,
        'isAuthDevice': false,
        'message': (data is Map ? data['message']?.toString() : null) ??
            'Login failed (${response.statusCode})',
      };
    }

    // Guard: response body must be a Map
    if (data is! Map) {
      print('Login failed: unexpected response type ${data.runtimeType}');
      return {
        'success': false,
        'isAuthDevice': false,
        'message': 'Unexpected server response',
      };
    }

    final map = Map<String, dynamic>.from(data);

    // Business failure (wrong credentials, user not found, etc.)
    if (map['success'] != true) {
      print('Login failed: ${map['message']}');
      return {
        'success': false,
        'isAuthDevice': map['isAuthDevice'] == true,
        'message': map['message']?.toString() ?? 'Login failed',
      };
    }

    // Device not authorized — backend still returns success:true
    if (map['isAuthDevice'] == false) {
      return {
        'success': true,
        'isAuthDevice': false,
        'message': map['message']?.toString() ?? 'Login failed',
      };
    }

    // Parse employee in its own try/catch so a model mismatch doesn't
    // kill the whole login flow.
    Employee? parsedEmployee;
    if (map['employee'] != null) {
      try {
        parsedEmployee = Employee.fromJson(
          Map<String, dynamic>.from(map['employee']),
        );
      } catch (e, st) {
        print('⚠️ Failed to parse employee: $e');
        print(st);
        // Fall through — login still succeeds, just without employee data.
      }
    }

    _currentEmployee = parsedEmployee;
    final code = _currentEmployee?.employeeId;

    await saveCredentials(
      map['token'].toString(),
      code,
      map['refreshToken']?.toString(),
    );

    // Return the original map so downstream callers keep getting the
    // same shape they used to.
    return map;
  } catch (e, st) {
    print('Login error: $e');
    print(st);
    return {
      'success': false,
      'isAuthDevice': false,
      'message': e.toString(),
    };
  }
}

  static Future<bool> RequestRefreshToken() async {
    try {
      final response = await ApiClient().dio.post('identity/refresh', options: Options(
        headers: getRefreshToken(),
      ));
      final data = response.data;
      if (response.statusCode == 200) {
        _currentEmployee = data['employee'] != null
            ? Employee.fromJson(data['employee'])
            : null;
        final code = _currentEmployee?.employeeId;
        await saveCredentials(data['token'], code, data['refreshToken']);
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  static Future<List<Designation>> getDesignations() async {
    // final resp = await http.get(
    //   Uri.parse('$API_BASE_URL/designation/list'),
    //   headers: getHeaders(),
    // );

    final response = await ApiClient().dio.get('designation/list');

    if (response.statusCode == 200) {
      final List data = response.data;
      return data.map((e) => Designation.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load designations');
    }
  }

  static Future<bool> validateTaskLocation({
    required String taskId,
    required double latitude,
    required double longitude,
  }) async {
    // final response = await http.post(
    //   Uri.parse('$API_BASE_URL/Task/validate-location'),
    //   headers: getHeaders(),
    //   body: jsonEncode({
    //     'taskId': taskId,
    //     'latitude': latitude,
    //     'longitude': longitude,
    //   }),
    // );

    final response = await ApiClient().dio.post(
      'Task/validate-location',
      data: {'taskId': taskId, 'latitude': latitude, 'longitude': longitude},
    );
    return response.statusCode == 200 && response.data == true;
  }

  // Check Holiday
  static Future<bool> isHoliday(String employeeCode, DateTime date) async {
    try {
      // Format the date properly
      String formattedDate =
          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

      // final response = await http
      //     .get(
      //       Uri.parse(
      //         '$API_BASE_URL/holiday/GetOffDay?empCode=$employeeCode&date=$formattedDate',
      //       ),
      //       headers: getHeaders(),
      //     )
      //     .timeout(const Duration(seconds: 30));

      final response = await ApiClient().dio.get(
        'holiday/GetOffDay?empCode=$employeeCode&date=$formattedDate',
        options: Options(receiveTimeout: const Duration(seconds: 30)),
      );

      if (response.data == 'true') {
        return true;
      }
      return false;
    } catch (e) {
      print('Is on Holiday error: $e');
      return false;
    }
  }

  //Check Employee On Leave
  static Future<bool> isOnLeave(String employeeId, String? companyCode) async {
    try {
      final response = await ApiClient().dio.get(
        'leave/isLeaveToday?employeeId=$employeeId&companyCode=$companyCode',
        options: Options(receiveTimeout: const Duration(seconds: 10)),
      );
      print('Leave Response: ${response.data}');
      if (response.data == true) {
        return true;
      }
      return false;
    } catch (e) {
      print('Is on leave error: $e');
      return false;
    }
  }

  // Get Today's Attendance
  static Future<AttendanceRecord?> getTodayAttendance(String employeeId) async {
    try {
      print('📊 Fetching today attendance for: $employeeId');

      // final response = await http
      //     .get(
      //       Uri.parse('$API_BASE_URL/attendance/$employeeId/today'),
      //       headers: getHeaders(),
      //     )
      //     .timeout(Duration(seconds: 10));
      final response = await ApiClient().dio.get(
        'attendance/$employeeId/today',
        options: Options(receiveTimeout: Duration(seconds: 10)),
      );
      if (response.statusCode == 200) {
        final body = response.data;

        // if (body != null && body is Map && body.containsKey('id')) {
        if (body != null && body is Map) {
          final data = Map<String, dynamic>.from(body);
          return AttendanceRecord.fromJson(data);
        }
      }

      return null;
    } catch (e) {
      print('Get today attendance error: $e');
      return null;
    }
  }

  // Get Leave Stats
  static Future<Map<String, dynamic>> getLeaveStatistics(String empCode) async {
    try {
      // final response = await http.get(
      //   Uri.parse('$API_BASE_URL/Leave/statistics/$empCode'),
      //   headers: getHeaders(),
      // );

      final response = await ApiClient().dio.get('Leave/statistics/$empCode');

      if (response.statusCode == 200) {
        return response.data;
      } else {
        return {'totalLeaves': 0, 'yearlyAvailed': 0, 'availableLeaves': 0};
      }
    } catch (e) {
      print('Error loading leave statistics: $e');
      return {'totalLeaves': 0, 'yearlyAvailed': 0, 'availableLeaves': 0};
    }
  }

  // Load Data for Cancel Leave
  static Future<DateTimeRange?> getLeaveCancelData({required int? no}) async {
    try {
      // final response = await http
      //     .get(
      //       Uri.parse('$API_BASE_URL/leave/getCancelLeaveDates?no=$no'),
      //       headers: getHeaders(),
      //     )
      //     .timeout(Duration(seconds: 10));

      final response = await ApiClient().dio.get(
        'leave/getCancelLeaveDates?no=$no',
        options: Options(receiveTimeout: Duration(seconds: 10)),
      );

      if (response.statusCode == 200) {
        final body = response.data;

        // Handle array/list response
        if (body != null && body is List) {
          if (body.isNotEmpty) {
            try {
              // Handle both string dates and timestamp formats
              String startStr = body[0].toString();
              String endStr = body[body.length - 1].toString();

              // Parse dates - adjust format based on your actual date format
              DateTime startDate = DateTime.parse(startStr);
              DateTime endDate = DateTime.parse(endStr);

              return DateTimeRange(start: startDate, end: endDate);
            } catch (e) {
              print('Date parsing error: $e');
            }
          }
        }
        // Also handle if it's a Map (for backward compatibility)
        else if (body != null && body is Map) {
          try {
            final data = Map<String, dynamic>.from(body);
            final startDate = DateTime.parse(data['startDate'].toString());
            final endDate = DateTime.parse(data['endDate'].toString());
            return DateTimeRange(start: startDate, end: endDate);
          } catch (e) {
            print('Map parsing error: $e');
          }
        }
      }
      return null;
    } catch (e) {
      print('Get leave cancel data error: $e');
      return null;
    }
  }

  static Future<bool> cancelLeaveDays({
    required String employeeId,
    required int leaveId,
    required List<DateTime> selectedDates,
    required String reason,
  }) async {
    try {
      // final response = await http.post(
      //   Uri.parse('$API_BASE_URL/leave/applycancelLeave'),
      //   headers: getHeaders(),
      //   body: json.encode({
      //     'employeeId': employeeId,
      //     'leaveId': leaveId,
      //     'dates': selectedDates
      //         .map((d) => d.toIso8601String().split('T').first)
      //         .toList(),
      //     'purpose': reason,
      //   }),
      // );

      final response = await ApiClient().dio.post(
        'leave/applycancelLeave',
        data: {
          'employeeId': employeeId,
          'leaveId': leaveId,
          'dates': selectedDates
              .map((d) => d.toIso8601String().split('T').first)
              .toList(),
          'purpose': reason,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        return data['success'] == true;
      }

      return false;
    } catch (e) {
      print('Error cancelling leave days: $e');
      return false;
    }
  }
  // static Future<List<EmployeeTaskReport>> getDailyReport(DateTime date, String managerId,) async {
  //     try {
  //       final uri = Uri.parse(
  //         '$API_BASE_URL/task/employee/dailyRecord',
  //       ).replace(queryParameters: {
  //         'date': date.toIso8601String().split('T')[0],
  //         'managerId': managerId,
  //       });

  //       final resp = await http
  //           .get(uri, headers: getHeaders())
  //           .timeout(const Duration(seconds: 20));

  //       if (resp.statusCode == 200) {
  //         final List list = jsonDecode(resp.body);
  //         return list
  //             .map((e) => EmployeeTaskReport.fromJson(e))
  //             .toList();
  //       }
  //       return [];
  //     } catch (e) {
  //       print('Daily task report error: $e');
  //       return [];
  //     }
  //   }

  //   /// MONTHLY REPORT
  //   static Future<List<EmployeeTaskReport>> getMonthlyReport(int year, int month, String managerId,) async {
  //     try {
  //       final uri = Uri.parse(
  //         '$API_BASE_URL/task/employee/monthlyRecord',
  //       ).replace(queryParameters: {
  //         'year': year.toString(),
  //         'month': month.toString(),
  //         'managerId': managerId,
  //       });

  //       final resp = await http
  //           .get(uri, headers: getHeaders())
  //           .timeout(const Duration(seconds: 20));

  //       if (resp.statusCode == 200) {
  //         final List list = jsonDecode(resp.body);
  //         return list
  //             .map((e) => EmployeeTaskReport.fromJson(e))
  //             .toList();
  //       }
  //       return [];
  //     } catch (e) {
  //       print('Monthly task report error: $e');
  //       return [];
  //     }
  //   }

  //   /// YEARLY REPORT
  //   static Future<List<EmployeeTaskReport>> getYearlyReport(int year, String managerId,) async {
  //     try {
  //       final uri = Uri.parse(
  //         '$API_BASE_URL/task/employee/yearlyRecord',
  //       ).replace(queryParameters: {
  //         'year': year.toString(),
  //         'managerId': managerId,
  //       });

  //       final resp = await http
  //           .get(uri, headers: getHeaders())
  //           .timeout(const Duration(seconds: 20));

  //       if (resp.statusCode == 200) {
  //         final List list = jsonDecode(resp.body);
  //         return list
  //             .map((e) => EmployeeTaskReport.fromJson(e))
  //             .toList();
  //       }
  //       return [];
  //     } catch (e) {
  //       print('Yearly task report error: $e');
  //       return [];
  //     }
  //   }

  /// DATE RANGE REPORT - Handles both single day and date ranges
  static Future<List<EmployeeTaskReport>> getDateRangeReport(
    DateTime startDate,
    DateTime endDate,
    String managerId,
  ) async {
    try {
      // final uri = Uri.parse('$API_BASE_URL/task/employee/dateRangeRecord')
      //     .replace(
      //       queryParameters: {
      //         'startDate': DateFormat('yyyy-MM-dd').format(startDate),
      //         'endDate': DateFormat('yyyy-MM-dd').format(endDate),
      //         'managerId': managerId,
      //       },
      //     );
      // final resp = await http
      //     .get(uri, headers: getHeaders())
      //     .timeout(const Duration(seconds: 20));

      final response = await ApiClient().dio.get(
        'task/employee/dateRangeRecord',
        queryParameters: {
          'startDate': DateFormat('yyyy-MM-dd').format(startDate),
          'endDate': DateFormat('yyyy-MM-dd').format(endDate),
          'managerId': managerId,
        },
        options: Options(receiveTimeout: const Duration(seconds: 20)),
      );

      if (response.statusCode == 200) {
        final List list = response.data;
        return list.map((e) => EmployeeTaskReport.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print('Date range task report error: $e');
      return [];
    }
  }

  // You can even remove getDailyReport now since it's redundant

  // // Cancel leave Request
  // static Future<bool> cancelSingleDayLeave({
  //   required String employeeId,
  //   required DateTime startDate,
  //   required DateTime endDate,
  //   required String reason,
  // }) async {
  //   try {
  //     final response = await http.post(
  //       Uri.parse('$API_BASE_URL/leave/applycancelLeave'),
  //       headers: getHeaders(),
  //       body: json.encode({
  //         'employeeId': employeeId, // Changed from 'empCode' to 'employeeId'
  //         'startDate': startDate.toIso8601String(),
  //         'endDate': endDate.toIso8601String(),
  //         'purpose': reason,
  //       }),
  //     );

  //     if (response.statusCode == 200) {
  //       final data = json.decode(response.body);
  //       return data['success'] == true || data['status'] == 'cancelled';
  //     }
  //     return false;
  //   } catch (e) {
  //     print('Error cancelling your leave(s): $e');
  //     return false;
  //   }
  // }

  // ApplyLeave
  static Future<Map<String, dynamic>> applyLeave({
    required String employeeId,
    required String leaveType,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
  }) async {
    try {
      // final response = await http
      //     .post(
      //       Uri.parse('$API_BASE_URL/leave/apply'),
      //       headers: getHeaders(),
      //       body: jsonEncode({
      //         'employeeId': employeeId,
      //         'leaveType': leaveType,
      //         'startDate': startDate.toIso8601String(),
      //         'endDate': endDate.toIso8601String(),
      //         'reason': reason,
      //       }),
      //     )
      //     .timeout(Duration(seconds: 30));

      final response = await ApiClient().dio.post(
        'leave/apply',
        data: {
          'employeeId': employeeId,
          'leaveType': leaveType,
          'startDate': startDate.toIso8601String(),
          'endDate': endDate.toIso8601String(),
          'reason': reason,
        },
        options: Options(receiveTimeout: Duration(seconds: 30)),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        final error = response.data;
        return {
          'success': false,
          'error': 'Failed to apply leave',
        };
      }
    } catch (e) {
      print('Apply leave error: $e');
      return {'success': false, 'error': 'Failed to apply leave'};
    }
  }

  static Future<List<LeaveType>> getLeaveTypes() async {
    try {
      // final resp = await http
      //     .get(Uri.parse('$API_BASE_URL/leave/types'), headers: getHeaders())
      //     .timeout(const Duration(seconds: 15));

      final response = await ApiClient().dio.get(
        'leave/types',
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );

      if (response.statusCode == 200) {
        final List list = response.data;
        return list.map((e) => LeaveType.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print('Get leave types error: $e');
      return [];
    }
  }

  // Get Leave Requests
  static Future<List<LeaveRequestModel>> getLeaveRequests(
    String employeeId,
  ) async {
    try {
      // final response = await http
      //     .get(
      //       Uri.parse('$API_BASE_URL/leave/$employeeId'),
      //       headers: getHeaders(),
      //     )
      //     .timeout(Duration(seconds: 30));

      final response = await ApiClient().dio.get(
        'leave/$employeeId',
        options: Options(receiveTimeout: Duration(seconds: 30)),
      );

      final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(
        response.data,
      );

      return data.map(LeaveRequestModel.fromJson).toList();

      //return [];
    } catch (e) {
      print('Get leave requests error: $e');
      return [];
    }
  }

  // Upload Profile Pic and waiting for approval
  static Future<Map<String, dynamic>> getNewProfileRequest(
    ApplyImageModel model,
  ) async {
    try {
      // final resp = await http
      //     .post(
      //       Uri.parse('$API_BASE_URL/RegistrationImage/apply'),
      //       headers: getHeaders(),
      //       body: jsonEncode(model.toJson()),
      //     )
      //     .timeout(const Duration(seconds: 20));

      final response = await ApiClient().dio.post(
        'RegistrationImage/apply',
        data: model.toJson(),
        options: Options(receiveTimeout: Duration(seconds: 20)),
      );
      if (response.statusCode == 200) {
        return response.data;
      } else {
        return {'success': false, 'message': response.data};
      }
    } catch (e) {
      print('Image Approval Sent Failed: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Get Profile Picture Request
  static Future<List<dynamic>> getEmployeeProfilePictureRequest(
    String employeeId,
  ) async {
    try {
      // final resp = await http
      //     .get(
      //       Uri.parse('$API_BASE_URL/RegistrationRequest/getlist'),
      //       headers: getHeaders(),
      //     )
      //     .timeout(const Duration(seconds: 20));

      final response = await ApiClient().dio.get(
        'RegistrationRequest/getlist',
        options: Options(receiveTimeout: const Duration(seconds: 20)),
      );

      if (response.statusCode == 200) {
        final List list = response.data;
        return list.map((e) => LeaveType.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print('Get leave types error: $e');
      return [];
    }
  }

  // Profile Pic Approved EndPoint
  static Future<Map<String, dynamic>> approveProfilePic(
    String approveId,
    ApprovePicModel model,
  ) async {
    try {
      print('Approve Profile: $model');

      // final response = await http
      //     .post(
      //       Uri.parse('$API_BASE_URL/RegistrationImage/Approverequest'),
      //       headers: getHeaders(),
      //       body: jsonEncode(model.toJson()),
      //     )
      //     .timeout(const Duration(seconds: 20));

      final response = await ApiClient().dio.post(
        'RegistrationImage/Approverequest',
        data: model.toJson(),
        options: Options(receiveTimeout: const Duration(seconds: 20)),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = response.data;
        final String imageBase64 = data['image'];
        final String empCode = data['empCode'];
        if (empCode == _currentEmployee?.employeeId) {
          _currentEmployee = _currentEmployee?.copyWith(
            faceImageBase64: imageBase64,
          );
        }

        return {'success': true, 'message': response.data};
      } else {
        return {'success': false, 'message': response.data};
      }
    } catch (e) {
      print('Approve Profile error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Get Notifications
  static Future<List<dynamic>> getNotifications(String employeeId) async {
    try {
      // final response = await http
      //     .get(
      //       Uri.parse('$API_BASE_URL/notification/$employeeId'),
      //       headers: getHeaders(),
      //     )
      //     .timeout(Duration(seconds: 10));

      final response = await ApiClient().dio.get(
        'notification/$employeeId',
        options: Options(receiveTimeout: const Duration(seconds: 10)),
      );

      if (response.statusCode == 200) {
        return response.data as List;
      }

      return [];
    } catch (e) {
      print('Get notifications error: $e');
      return [];
    }
  }

  // Mark Notification as Read
  static Future<bool> markNotificationAsRead(String notificationId) async {
    try {
      // final response = await http
      //     .put(
      //       Uri.parse('$API_BASE_URL/notification/$notificationId/read'),
      //       headers: getHeaders(),
      //     )
      //     .timeout(Duration(seconds: 10));

      final response = await ApiClient().dio.put(
        'notification/$notificationId/read',
        options: Options(receiveTimeout: Duration(seconds: 10)),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Mark notification error: $e');
      return false;
    }
  }

  //Download Manager Report
  static Future<Uint8List?> downloadManagerReportBytes(
    String reportType,
    DateTime date,
    String mangerId,
  ) async {
    try {
      // Format date based on report type
      String formattedDate;
      if (reportType.toLowerCase() == 'Monthly') {
        formattedDate =
            "${date.year}-${date.month.toString().padLeft(2, '0')}-01";
      } else {
        formattedDate = date.toIso8601String().split('T')[0];
      }

      // final url = Uri.parse('$API_BASE_URL/report/getExportByManager').replace(
      //   queryParameters: {
      //     'date': formattedDate,
      //     'reportType': reportType,
      //     'managerId': mangerId,
      //   },
      // );
      // final response = await http
      //     .get(url, headers: getHeaders())
      //     .timeout(Duration(seconds: 30));

      final response = await ApiClient().dio.get(
        'report/getExportByManager',
        queryParameters: {
          'date': formattedDate,
          'reportType': reportType,
          'managerId': mangerId,
        },
        options: Options(receiveTimeout: Duration(seconds: 30)),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        print('Server error: ${response.statusCode} - ${response.data}');
        return null;
      }
    } catch (e) {
      print('Download error: $e');
      return null;
    }
  }

  //Download Employee Report
  static Future<Uint8List?> downloadEmployeeReportBytes(
    String reportType,
    DateTime startDate,
    DateTime endDate,
    String empId,
  ) async {
    try {
      final String startFormatted = startDate.toIso8601String().split('T')[0];
      final String endFormatted = endDate.toIso8601String().split('T')[0];

      // final url = Uri.parse('$API_BASE_URL/report/getExportByEmployee').replace(
      //   queryParameters: {
      //     'startDate': startFormatted,
      //     'endDate': endFormatted,
      //     'reportType': reportType,
      //     'empId': empId,
      //   },
      // );

      // print('Downloading from: $url');

      // final response = await http
      //     .get(url, headers: getHeaders())
      //     .timeout(Duration(seconds: 30));

      final response = await ApiClient().dio.get(
        'report/getExportByEmployee',
        queryParameters: {
          'startDate': startFormatted,
          'endDate': endFormatted,
          'reportType': reportType,
          'empId': empId,
        },
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 30),
          validateStatus: (status) => status != null,
        ),
      );

      if (response.statusCode == 200) {
        return Uint8List.fromList(response.data as List<int>);
      } else {
        print('Server error: ${response.statusCode} - ${response.data}');
        return null;
      }
    } catch (e) {
      print('Download error: $e');
      return null;
    }
  }

  // Get Attendance History
  static Future<List<AttendanceRecord>> getAttendanceHistory(
    String employeeId, {
    int days = 30,
  }) async {
    try {
      print('📜 Fetching attendance history for: $employeeId');
      // final response = await http
      //     .get(
      //       Uri.parse('$API_BASE_URL/attendance/$employeeId?days=$days'),
      //       headers: getHeaders(),
      //     )
      //     .timeout(Duration(seconds: 10));

      final response = await ApiClient().dio.get(
        'attendance/$employeeId?days=$days',
        options: Options(receiveTimeout: Duration(seconds: 10)),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => AttendanceRecord.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      print('Get history error: $e');
      return [];
    }
  }

  // Check In
  static Future<Map<String, dynamic>> checkIn({
    required String employeeId,
    required double latitude,
    required double longitude,
    required String? checkInAddress,
    String? photoBase64,
  }) async {
    try {
      print(' Attempting check-in for: $employeeId');
      print('📍 Location: $latitude, $longitude');

      // final response = await http
      //     .post(
      //       Uri.parse('$API_BASE_URL/attendance/check-in'),
      //       headers: getHeaders(),
      //       body: jsonEncode({
      //         'employeeId': employeeId,
      //         'latitude': latitude,
      //         'longitude': longitude,
      //         'photoBase64': photoBase64 ?? '',
      //       }),
      //     )
      //     .timeout(Duration(seconds: 90));

      final response = await ApiClient().dio.post(
        'attendance/check-in',
        data: {
          'employeeId': employeeId,
          'latitude': latitude,
          'longitude': longitude,
          'checkInAddress': checkInAddress ?? '',
          'photoBase64': photoBase64 ?? '',
        },
        options: Options(receiveTimeout: Duration(seconds: 90)),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        final error = response.data;
        return {'success': false, 'error': error['error'] ?? 'Check-in failed'};
      }
    } catch (e) {
      print('Check-in error: $e');
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // Check Out
  static Future<Map<String, dynamic>> checkOut({
    required String employeeId,
    required double latitude,
    required double longitude,
    required String? checkOutAddress,
    String? photoBase64,
  }) async {
    try {
      // final response = await http
      //     .post(
      //       Uri.parse('$API_BASE_URL/attendance/check-out'),
      //       headers: getHeaders(),
      //       body: jsonEncode({
      //         'employeeId': employeeId,
      //         'latitude': latitude,
      //         'longitude': longitude,
      //         'photoBase64': photoBase64 ?? '',
      //       }),
      //     )
      //     .timeout(Duration(seconds: 90));

      final response = await ApiClient().dio.post(
        'attendance/check-out',
        data: {
          'employeeId': employeeId,
          'latitude': latitude,
          'longitude': longitude,
          'checkOutAddress': checkOutAddress ?? '',
          'photoBase64': photoBase64 ?? '',
        },
        options: Options(receiveTimeout: Duration(seconds: 90)),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        final error = response.data;
        return {
          'success': false,
          'error': error['error'] ?? 'Check-out failed',
        };
      }
    } catch (e) {
      print('Check-out error: $e');
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // Get Summary
  static Future<Map<String, dynamic>?> getSummary(String employeeId) async {
    try {
      // final response = await http
      //     .get(
      //       Uri.parse(
      //         '$API_BASE_URL/attendance/summary?employeeId=$employeeId',
      //       ),
      //       headers: getHeaders(),
      //     )
      //     .timeout(Duration(seconds: 10));

      final response = await ApiClient().dio.get(
        'attendance/summary?employeeId=$employeeId',
        options: Options(receiveTimeout: Duration(seconds: 10)),
      );

      if (response.statusCode == 200) {
        return response.data;
      }

      return null;
    } catch (e) {
      print('Get summary error: $e');
      return null;
    }
  }

  static Future<List<TaskModel>> getActiveTasks(String employeeId) async {
    try {
      // final response = await http
      //     .get(
      //       Uri.parse('$API_BASE_URL/task/employee/$employeeId/active'),
      //       headers: getHeaders(),
      //     )
      //     .timeout(Duration(seconds: 10));

      final response = await ApiClient().dio.get(
        'task/employee/$employeeId/active',
        options: Options(receiveTimeout: Duration(seconds: 10)),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => TaskModel.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      print('Get tasks error: $e');
      return [];
    }
  }

  // Start Task
  static Future<Map<String, dynamic>> startTask({
    required String employeeId,
    required String taskId,
  }) async {
    try {
      // final response = await http
      //     .post(
      //       Uri.parse('$API_BASE_URL/task/start'),
      //       headers: getHeaders(),
      //       body: jsonEncode({'employeeId': employeeId, 'taskId': taskId}),
      //     )
      //     .timeout(Duration(seconds: 10));

      final response = await ApiClient().dio.post(
        'task/start',
        data: {'employeeId': employeeId, 'taskId': taskId},
        options: Options(receiveTimeout: const Duration(seconds: 10)),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        final error = response.data;
        return {'success': false, 'error': error['error']};
      }
    } catch (e) {
      print('Start task error: $e');
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  static Future<bool> exportTaskReport(
    ExportRequest request, {
    bool share = true,
  }) async {
    try {
      // Build query parameters from the request object
      // final queryParams = {
      //   'StartDate': request.startDate?.toIso8601String(),
      //   'EndDate': request.endDate?.toIso8601String(),
      //   'ManagerId': request.managerId,
      //   if (request.employeeId != null) 'EmployeeId': request.employeeId,
      //   if (request.viewType != null) 'ViewType': request.viewType,
      // };

      // final uri = Uri.parse(
      //   '$API_BASE_URL/task/task-report',
      // ).replace(queryParameters: queryParams);

      // print('Export URL: $uri');

      // final response = await http
      //     .get(uri, headers: getHeaders())
      //     .timeout(const Duration(seconds: 30));

      final response = await ApiClient().dio.get(
        'task/task-report',
        queryParameters: {
          'StartDate': request.startDate?.toIso8601String(),
          'EndDate': request.endDate?.toIso8601String(),
          'ManagerId': request.managerId,
          if (request.employeeId != null) 'EmployeeId': request.employeeId,
          if (request.viewType != null) 'ViewType': request.viewType,
        },
        options: Options(responseType: ResponseType.bytes,receiveTimeout: const Duration(seconds: 30)),
      );

      if (response.statusCode == 200) {
        // Save the file
        final directory = await getApplicationDocumentsDirectory();
        final fileName = _getExportFileName(request);
        final filePath = '${directory.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(response.data);

        print('File saved at: $filePath');
        print('File size: ${await file.length()} bytes');

        if (share) {
          await Share.shareXFiles([
            XFile(filePath),
          ], text: 'Task Report Export');
        } else {
          final result = await OpenFilex.open(filePath);
          print('📱 Open result: ${result.type} - ${result.message}');

          if (result.type != ResultType.done) {
            print('⚠️ Opening failed, falling back to share');
            await Share.shareXFiles([XFile(filePath)]);
          }
        }

        return true;
      } else {
        print('Export failed: ${response.statusCode} - ${response.data}');
        return false;
      }
    } catch (e) {
      print('Export error: $e');
      return false;
    }
  }

  static String _getExportFileName(ExportRequest request) {
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final startStr = DateFormat('yyyyMMdd').format(request.startDate);
    final endStr = DateFormat('yyyyMMdd').format(request.endDate);

    String periodStr;
    if (startStr == endStr) {
      periodStr = '_$startStr'; // Single day
    } else {
      periodStr = '_${startStr}_to_$endStr'; // Date range
    }

    if (request.employeeId != null) {
      return 'Task_Report_Selected_Employee$periodStr.xlsx';
    } else {
      return 'Task_Report_All_Employees$periodStr.xlsx';
    }
  }

  // Stop Task
  static Future<Map<String, dynamic>> stopTask({
    required String employeeId,
    required String taskId,
    String notes = '',
  }) async {
    try {
      // final response = await http
      //     .post(
      //       Uri.parse('$API_BASE_URL/task/stop'),
      //       headers: getHeaders(),
      //       body: jsonEncode({
      //         'employeeId': employeeId,
      //         'taskId': taskId,
      //         'notes': notes,
      //       }),
      //     )
      //     .timeout(Duration(seconds: 10));

      final response = await ApiClient().dio.post(
        'task/stop',
        data: {'employeeId': employeeId, 'taskId': taskId, 'notes': notes},
        options: Options(receiveTimeout: const Duration(seconds: 10)),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        final error = response.data;
        return {'success': false, 'error': error['error']};
      }
    } catch (e) {
      print('Stop task error: $e');

      if (e is DioException) {
        print('Status: ${e.response?.statusCode}');
        print('Response: ${e.response?.data}');
        print('Message: ${e.message}');
        print('Type: ${e.type}');

        final serverData = e.response?.data;
        final errorMessage = (serverData is Map && serverData['error'] != null)
            ? serverData['error']
            : e.message ?? 'Something went wrong';

        return {'success': false, 'error': errorMessage};
      }

      return {'success': false, 'error': e.toString()};
    }
  }

  // Complete Task
  static Future<Map<String, dynamic>> completeTask({
    required String employeeId,
    required String taskId,
  }) async {
    try {
      // final response = await http
      //     .post(
      //       Uri.parse('$API_BASE_URL/task/$taskId/complete'),
      //       headers: getHeaders(),
      //       body: jsonEncode({'employeeId': employeeId}),
      //     )
      //     .timeout(Duration(seconds: 10));

      final response = await ApiClient().dio.post(
        'task/$taskId/complete',
        data: {'employeeId': employeeId},
        options: Options(receiveTimeout: const Duration(seconds: 10)),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        final error = response.data;
        return {'success': false, 'error': error['error']};
      }
    } catch (e) {
      print('Complete task error: $e');
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  static Future<bool> updateTask(Map<String, dynamic> taskData) async {
    try {
      // final response = await http
      //     .patch(
      //       Uri.parse('$API_BASE_URL/task/update'),
      //       headers: getHeaders(),
      //       body: jsonEncode(taskData),
      //     )
      //     .timeout(Duration(seconds: 15));

      final response = await ApiClient().dio.patch(
        'task/update',
        data: taskData,
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );

      if (response.statusCode == 200) {
        final responseData = response.data;
        return responseData['success'] == true;
      } else {
        print('Failed to update task. Status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error updating task: $e');
      return false;
    }
  }

  static Future<bool> deleteTask(String taskId, String leadCode) async {
    try {
      // final response = await http
      //     .patch(
      //       Uri.parse('$API_BASE_URL/task/delete'),
      //       headers: getHeaders(),
      //       body: jsonEncode({'taskId': taskId, 'leadCode': leadCode}),
      //     )
      //     .timeout(Duration(seconds: 15));

      final response = await ApiClient().dio.patch(
        'task/delete',
        data: {'taskId': taskId, 'leadCode': leadCode},
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );

      if (response.statusCode == 200) {
        final responseData = response.data;
        return responseData['success'] == true;
      } else {
        print('Failed to delete task. Status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error deleting task: $e');
      return false;
    }
  }

  // Leaves Approvals
  static Future<List<dynamic>> getPendingLeaveApprovals(
    String managerId,
  ) async {
    try {
      print('Fetching pending approvals for manager: $managerId');
      // final response = await http
      //     .get(
      //       Uri.parse('$API_BASE_URL/leave/pending-approvals/$managerId'),
      //       headers: getHeaders(),
      //     )
      //     .timeout(Duration(seconds: 10));

      final response = await ApiClient().dio.get(
        'leave/pending-approvals/$managerId',
        options: Options(receiveTimeout: const Duration(seconds: 10)),
      );

      print('Pending approvals response: ${response.statusCode}');

      if (response.statusCode == 200) {
        return response.data as List;
      }

      return [];
    } catch (e) {
      print('Get pending approvals error: $e');
      return [];
    }
  }

  //OverTime Approvals
  static Future<List<dynamic>> getOverTimeApprovals(String managerId) async {
    try {
      final response = await ApiClient().dio.get(
        'TaskOverTime/pending-overtime-approvals/$managerId',
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );

    if (response.statusCode == 200) {
        final jsonResponse = response.data;
        final apiResponse = Overtimeresponse.fromJson(jsonResponse);

        if (apiResponse.success) {
          print(
            'Successfully fetched ${apiResponse.overtime.length} overtime requests',
          );
          return apiResponse.overtime;
        } else {
          print('API error: ${apiResponse.error}');
          return [];
        }
      } else {
        return [];
      }
    } catch (ex) {
      print('Get Cancel Leave Approvals Error: $ex');
      return [];
    }
  }

  //Approve Overtime
  static Future<Map<String, dynamic>> approveOvertimeRequest(String taskId) async {
    try {
      final response = await ApiClient().dio.post(
        'TaskOverTime/approve',
        queryParameters: {'taskId': taskId},
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );

      print("APPROVE OVERTIME RESPONSE: ${response.data}");

      if (response.statusCode == 200) {
        final jsonResponse = response.data;
        return {
          'success': jsonResponse['success'] ?? false,
          'error': jsonResponse['error'] ?? jsonResponse['message'],
        };
      } else {
        return {'success': false, 'error': 'Failed to approve overtime'};
      }
    } catch (ex) {
      print('Approve Overtime Error: $ex');
      return {'success': false, 'error': ex.toString()};
    }
  }

  //Reject
  static Future<Map<String, dynamic>> rejectOvertimeRequest(String taskId, String reason) async {
    try {
      final response = await ApiClient().dio.post(
        'TaskOverTime/reject',
        data: {'taskId': taskId, 'reason': reason},
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );

      print("REJECT OVERTIME RESPONSE: ${response.data}");

      if (response.statusCode == 200) {
        final jsonResponse = response.data;
        return {
          'success': jsonResponse['success'] ?? false,
          'error': jsonResponse['error'] ?? jsonResponse['message'],
        };
      } else {
        return {'success': false, 'error': 'Failed to reject overtime'};
      }
    } catch (ex) {
      print('Reject Overtime Error: $ex');
      return {'success': false, 'error': ex.toString()};
    }
  }

  // Cancel Leaves Approvals
  static Future<List<dynamic>> getPendingCancelLeaveApprovals(
    String leadCode,
  ) async {
    try {
      print('📋 Fetching pending approvals for manager: $leadCode');

      final response = await ApiClient().dio.get(
        'leave/pending-cancel-approvals/$leadCode',
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );

      print('Status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonResponse = response.data;
        final apiResponse = ApiLeaveResponse.fromJson(jsonResponse);

        if (apiResponse.success) {
          print(
            'Successfully fetched ${apiResponse.leave.length} leave requests',
          );
          return apiResponse.leave;
        } else {
          print('API error: ${apiResponse.error}');
          return [];
        }
      } else {
        return [];
      }
    } catch (ex) {
      print('Get Cancel Leave Approvals Error: $ex');
      return [];
    }
  }

  // NEW: Approve Leave Request
  static Future<Map<String, dynamic>> approveLeave(int leaveId) async {
    try {
      print(' Approving leave: $leaveId');
      // final approverId = ApiService._employeeId;
      final approverId = ApiService.currentEmployee?.employeeId;
      // final response = await http
      //     .post(
      //       Uri.parse('$API_BASE_URL/leave/$leaveId/approve'),
      //       headers: getHeaders(),
      //       body: jsonEncode({"approverId": approverId}),
      //     )
      //     .timeout(Duration(seconds: 10));

      final response = await ApiClient().dio.post(
        'leave/$leaveId/approve',
        data: {"approverId": approverId},
        options: Options(receiveTimeout: const Duration(seconds: 10)),
      );

      print('📡 Approve leave response: ${response.statusCode}');

      if (response.statusCode == 200) {
        return response.data;
      } else {
        final error = response.data;
        return {
          'success': false,
          'error': error['error'] ?? 'Failed to approve',
        };
      }
    } catch (e) {
      print('Approve leave error: $e');
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // Cancel Leave Request
  static Future<Map<String, dynamic>> approveCancelRequest(String id) async {
    try {
      print(' Approving leave: $id');
      // final approverId = ApiService._employeeId;
      final approverId = ApiService.currentEmployee?.employeeId;
      // final response = await http
      //     .post(
      //       Uri.parse(
      //         '$API_BASE_URL/leave/$id/approvecancelRequest?approverId=$approverId',
      //       ),
      //       headers: getHeaders(),
      //     )
      //     .timeout(Duration(seconds: 15));

      final response = await ApiClient().dio.post(
        'leave/$id/approvecancelRequest?approverId=$approverId',
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );

      print('📡 Approve leave response: ${response.statusCode}');

      if (response.statusCode == 200) {
        return response.data;
      } else {
        final error = response.data;
        return {
          'success': false,
          'error': error['error'] ?? 'Failed to approve',
        };
      }
    } catch (e) {
      print('Approve leave error: $e');
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // NEW: Reject Leave Request
  static Future<Map<String, dynamic>> rejectLeave(
    int leaveId,
    String reason,
  ) async {
    // final approverId = ApiService._employeeId;
    final approverId = ApiService.currentEmployee?.employeeId;
    try {
      print('Rejecting leave: $leaveId');
      // final response = await http
      //     .post(
      //       Uri.parse('$API_BASE_URL/leave/$leaveId/reject'),
      //       headers: getHeaders(),
      //       body: jsonEncode({'approverId': approverId, 'reason': reason}),
      //     )
      //     .timeout(Duration(seconds: 10));
      final response = await ApiClient().dio.post(
        'leave/$leaveId/reject',
        data: {'approverId': approverId, 'reason': reason},
        options: Options(receiveTimeout: const Duration(seconds: 10)),
      );
      print('📡 Reject leave response: ${response.statusCode}');

      if (response.statusCode == 200) {
        return response.data;
      } else {
        final error = response.data;
        return {
          'success': false,
          'error': error['error'] ?? 'Failed to reject',
        };
      }
    } catch (e) {
      print('Reject leave error: $e');
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // Reject Leave Request
  static Future<Map<String, dynamic>> rejectLeaveCancelRequest(
    String leaveId,
    String reason,
  ) async {
    // final approverId = ApiService._employeeId;
    final approverId = ApiService.currentEmployee?.employeeId;
    try {
      print('Rejecting leave: $leaveId');
      // final response = await http
      //     .post(
      //       Uri.parse('$API_BASE_URL/leave/$leaveId/rejectCancelLeave'),
      //       headers: getHeaders(),
      //       body: jsonEncode({'approverId': approverId, 'reason': reason}),
      //     )
      //     .timeout(Duration(seconds: 10));

      final response = await ApiClient().dio.post(
        'leave/$leaveId/rejectCancelLeave',
        data: {'approverId': approverId, 'reason': reason},
        options: Options(receiveTimeout: const Duration(seconds: 10)),
      );

      print('📡 Reject leave response: ${response.statusCode}');

      if (response.statusCode == 200) {
        return response.data;
      } else {
        final error = response.data;
        return {
          'success': false,
          'error': error['error'] ?? 'Failed to reject',
        };
      }
    } catch (e) {
      print('Reject leave error: $e');
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // NEW: Get Clients
  static Future<List<dynamic>> getClients() async {
    try {
      // final response = await http
      //     .get(Uri.parse('$API_BASE_URL/entity/all'), headers: getHeaders())
      //     .timeout(Duration(seconds: 30));

      final response = await ApiClient().dio.get(
        'entity/all',
        options: Options(receiveTimeout: const Duration(seconds: 30)),
      );

      if (response.statusCode == 200) {
        return response.data as List;
      } else {
        return [];
      }
    } catch (e) {
      print('Get team members error: $e');
      return [];
    }
  }

  static Future<List<dynamic>> getDevices() async {
    try {
      // final response = await http
      //     .get(Uri.parse('$API_BASE_URL/device'), headers: getHeaders())
      //     .timeout(Duration(seconds: 30));
      final response = await ApiClient().dio.get(
        'device',
        options: Options(receiveTimeout: const Duration(seconds: 30)),
      );
      if (response.statusCode == 200) {
        return response.data as List;
      } else {
        return [];
      }
    } catch (e) {
      print(' Get Devices error: $e');
      return [];
    }
  }

  // Profile Picture Approval
  static Future<List<EmployeeProfileModel>> getEmployeeProfileData(
    String employeeId,
  ) async {
    try {
      // final resp = await http
      //     .get(
      //       Uri.parse('$API_BASE_URL/RegistrationImage/getlist'),
      //       headers: getHeaders(),
      //     )
      //     .timeout(const Duration(seconds: 15));
      final response = await ApiClient().dio.get(
        'RegistrationImage/getlist',
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );
      if (response.statusCode == 200) {
        final decoded = response.data;

        //  If response is wrapped
        final List list = decoded['data'];

        return list.map((e) => EmployeeProfileModel.fromJson(e)).toList();
      } else {
        throw Exception('Failed to fetch employee profiles');
      }
    } catch (e) {
      print('Get leave types error: $e');
      return [];
    }
  }

  // Profile Pic Approval
  // static Future<Map<String, dynamic>> approveProfilePic(
  //   String approveId,
  //   EmployeeProfileModel model,
  // ) async {
  //   try {
  //     print(' Approve Profile: $approveId');

  //     final response = await http
  //         .post(
  //           Uri.parse(
  //             '$API_BASE_URL/RegistrationRequest/$approveId/ApproveRequest',
  //           ),
  //           headers: getHeaders(),
  //           body: jsonEncode(model.toJson()),
  //         )
  //         .timeout(const Duration(seconds: 20));

  //     if (response.statusCode == 200) {
  //       return jsonDecode(response.body);
  //     } else {
  //       return {
  //         'success': false,
  //         'message': response.body,
  //       };
  //     }
  //   } catch (e) {
  //     print('Approve Profile error: $e');
  //     return {'success': false, 'error': e.toString()};
  //   }
  // }

  static Future<Map<String, dynamic>> deleteDevice(String deviceId) async {
    // final url = '$API_BASE_URL/device/Delete?DeviceId=$deviceId';
    // final resp = await http.delete(Uri.parse(url), headers: getHeaders());

    final response = await ApiClient().dio.delete(
      'device/Delete?DeviceId=$deviceId',
    );

    if (response.statusCode == 200) {
      return response.data;
    } else {
      return {'success': false, 'error': 'Failed to delete device'};
    }
  }

  static Future<List<TeamMember>> getTeamMembers(String managerId) async {
    try {
      print('👥 Fetching team members for manager: $managerId');
      
      // Add cache-busting timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      final response = await ApiClient().dio.get(
        'employee/$managerId/team',
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          headers: {
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
            'Expires': '0',
          },
        ),
        queryParameters: {
          '_t': timestamp, // This prevents caching
        },
      );

      if (response.statusCode == 200) {
        final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(
          response.data,
        );
        return data.map(TeamMember.fromJson).toList();
      }
      return [];
    } catch (e) {
      print('Get team members error: $e');
      return [];
    }
  }

  static Future<List<dynamic>> getUserRoles() async {
    // final url = '$API_BASE_URL/identity/getUserRoles';
    // final resp = await http.get(Uri.parse(url), headers: getHeaders());

    final response = await ApiClient().dio.get('identity/getUserRoles');

    if (response.statusCode == 200) {
      return response.data;
    } else {
      throw Exception('Failed to fetch roles');
    }
  }

  static Future<List<dynamic>> getDepartments() async {
    // final url = '$API_BASE_URL/department/list';
    // final resp = await http.get(Uri.parse(url), headers: getHeaders());

    final response = await ApiClient().dio.get('department/list');

    if (response.statusCode == 200) {
      return response.data; // List of department JSON
    } else {
      throw Exception('Failed to fetch departments');
    }
  }

  static Future<List<dynamic>> getCompanies() async {
    // final url = '$API_BASE_URL/company/list'; // backend endpoint
    // final resp = await http.get(Uri.parse(url), headers: getHeaders());

    final response = await ApiClient().dio.get('company/list');

    if (response.statusCode == 200) {
      return response.data; // should return a List of companies
    } else {
      throw Exception('Failed to fetch companies');
    }
  }

  static Future<List<Priority>> getPriorities() async {
    // final response = await http.get(
    //   Uri.parse('$API_BASE_URL/task/GetPriorities'),
    // );

    final response = await ApiClient().dio.get('task/GetPriorities');

    final decoded = response.data;

    if (decoded['success'] == true) {
      final List list = decoded['priorities'];
      return list.map((e) => Priority.fromJson(e)).toList();
    } else {
      throw Exception("Failed to load priorities");
    }
  }

  // Assign Task
  // Update the assignTask method to handle multiple assignments
  static Future<Map<String, dynamic>> assignTask({
    required String assignedBy,
    required String assignedTo,
    required String taskTitle,
    required String taskDescription,
    required DateTime dueDate,
    required String priority,
    required String taskPreference,
    required String client,
  }) async {
    try {
      print('📝 Assigning task: $taskTitle to: $assignedTo');
      // final response = await http
      //     .post(
      //       Uri.parse('$API_BASE_URL/task/assign'),
      //       headers: getHeaders(),
      //       body: jsonEncode({
      //         'assignedBy': assignedBy,
      //         'assignedTo': assignedTo,
      //         'taskTitle': taskTitle,
      //         'taskDescription': taskDescription,
      //         'dueDate': dueDate.toIso8601String(),
      //         'priority': priority,
      //         'client': client,
      //         'taskPreference': taskPreference,
      //       }),
      //     )
      //     .timeout(Duration(seconds: 70));

      final response = await ApiClient().dio.post(
        'task/assign',
        data: {
          'assignedBy': assignedBy,
          'assignedTo': assignedTo,
          'taskTitle': taskTitle,
          'taskDescription': taskDescription,
          'dueDate': dueDate.toIso8601String(),
          'priority': priority,
          'client': client,
          'taskPreference': taskPreference,
        },
        options: Options(receiveTimeout: Duration(seconds: 70)),
      );

      print('📡 Assign task response: ${response.statusCode}');

      if (response.statusCode == 200) {
        return response.data;
      } else {
        final error = response.data;
        return {
          'success': false,
          'error': error['error'] ?? 'Failed to assign task',
        };
      }
    } catch (e) {
      print('Assign task error: $e');
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // Optional: New method for bulk assignment
  static Future<Map<String, dynamic>> assignTaskToMultiple({
    required String assignedBy,
    required List<String> assignedToList,
    required String taskTitle,
    required String taskDescription,
    required DateTime dueDate,
    required String priority,
    required String taskPreference,
    required String client,
  }) async {
    try {
      print('📝 Assigning task to multiple users: $taskTitle');
      final response = await ApiClient().dio.post(
        'task/assign-multiple',
        data: {
          'assignedBy': assignedBy,
          'assignedTo': assignedToList,
          'taskTitle': taskTitle,
          'taskDescription': taskDescription,
          'dueDate': dueDate.toIso8601String(),
          'priority': priority,
          'client': client,
          'taskPreference': taskPreference,
        },
        options: Options(receiveTimeout: Duration(seconds: 70)),
      );
      if (response.statusCode == 200) {
        return response.data;
      } else {
        final error = response.data;
        return {
          'success': false,
          'error': error['error'] ?? 'Failed to assign task',
        };
      }
    } catch (e) {
      print('Bulk assign task error: $e');
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // StandardHourGroup
  static Future<Map<String, dynamic>> addEmp({
  required String managerId,
  required String zkUserId,
  required String firstName,
  required String lastName,
  required String email,
  required String phone,
  required String companyCode,
  required String department,
  required int designation,          // -> designationCode (int)
  String? designationName,           // -> designation (string)
  required bool isActive,
  required DateTime joinDate,
  required String role,
  required bool userStatus,          // -> isAppUser
  required String? roleId,
  required int standardHourCode,     // -> standardHour
}) async {
  try {
    final response = await ApiClient().dio.post(
      'Identity/createuser',
      data: {
        'managerId': managerId,
        'zkUserId': zkUserId,
        'firstName': firstName,
        'lastName': lastName,
        'companyCode': companyCode,
        'email': email,
        'phone': phone,
        'department': department,
        'designationCode': designation,     
        'designation': designationName,     
        'standardHour': standardHourCode,   
        'isAppUser': userStatus,
        'isActive': isActive,
        'joinDate': joinDate.toIso8601String(),
        'role': role,
        'roleId': roleId?.toString(),
      },
      options: Options(receiveTimeout: const Duration(seconds: 30)),
    );

    if (response.statusCode == 200) {
      return response.data;
    } else {
      final error = response.data;
      return {
        'success': false,
        'error': error['error'] ??
            'Failed to create the Employee. Please try again',
      };
    }
  } on DioException catch (e) {
    // Surfaces the real ValidationProblemDetails body instead of a generic message
    print('Employee Setup DioException: ${e.response?.statusCode} ${e.response?.data}');
    return {
      'success': false,
      'error': e.response?.data?['error'] ??
          e.response?.data?.toString() ??
          'Connection error: ${e.message}',
    };
  } catch (e) {
    print('Employee Setup error: $e');
    return {'success': false, 'error': 'Connection error: $e'};
  }
}
  // Edit Employee
  static Future<Map<String, dynamic>> editEmp({
    required String empCode,
    required String managerId,
    required String newEmpId,
    required String zkUserId,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String companyCode,
    required String department,
    required int designation,
    required bool isActive,
    required DateTime joinDate,
    required String role,
    required bool userStatus,
    required String? roleId,
    required int standardHourCode,
  }) async {
    try {
      // final url = '$API_BASE_URL/employee/editEmployeeAndUser';
      // final resp = await http
      //     .post(
      //       Uri.parse(url),
      //       headers: getHeaders(),
      //       body: jsonEncode({
      //         'managerId': managerId,
      //         'employeeId': newEmpId,
      //         'zkUserId': zkUserId,
      //         'firstName': firstName,
      //         'lastName': lastName,
      //         'companyCode': companyCode,
      //         'email': email,
      //         'phone': phone,
      //         'departmentCode': department,
      //         'designationCode': designation,
      //         'IsAppUser': userStatus,
      //         'isActive': isActive,
      //         'joinDate': joinDate.toIso8601String(),
      //         'roleId': roleId,
      //         'StandardHour': standardHourCode,
      //       }),
      //     )
      //     .timeout(Duration(seconds: 30));

      final response = await ApiClient().dio.post(
        'employee/editEmployeeAndUser',
        data: {
          'managerId': managerId,
          'employeeId': newEmpId,
          'zkUserId': zkUserId,
          'firstName': firstName,
          'lastName': lastName,
          'companyCode': companyCode,
          'email': email,
          'phone': phone,
          'departmentCode': department,
          'designationCode': designation,
          'IsAppUser': userStatus,
          'isActive': isActive,
          'joinDate': joinDate.toIso8601String(),
          'roleId': roleId,
          'StandardHour': standardHourCode,
        },
        options: Options(receiveTimeout: Duration(seconds: 30)),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        final error = response.data;
        return {
          'success': false,
          'error':
              error['error'] ?? 'Failed to edit the Employee. Please try again',
        };
      }
    } catch (e) {
      print('Employee Setup error: $e');
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  static Future<List<StandardHourGroup>> getStandardHours() async {
    // final resp = await http.get(
    //   Uri.parse('$API_BASE_URL/identity/getStandardGroup'),
    //   headers: getHeaders(),
    // );

    final response = await ApiClient().dio.get('identity/getStandardGroup');

    if (response.statusCode == 200) {
      final List data = response.data;
      return data.map((e) => StandardHourGroup.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load standardHourGroup');
    }
  }

  static Future<List<dynamic>> getTeamLeads() async {
    // final url = '$API_BASE_URL/employee/teamLeadsList';
    // final resp = await http.get(Uri.parse(url), headers: getHeaders());

    final response = await ApiClient().dio.get('employee/teamLeadsList');

    if (response.statusCode == 200) {
      return response.data;
    } else {
      throw Exception('Failed to fetch team lead');
    }
  }

  // Add Client
  static Future<Map<String, dynamic>> addClient({
    required String clientCode,
    required String clientName,
    required String clientSuitNo,
    required String clientSteetNO,
    required String clientPostalCode,
    required String clientTown,
    required String clientProvince,
    required String clientCountry,
    required String clientEmail,
    required String clientPhone,
    required String clientLegalName,
    String? clientIndustryCode,
    String? clientFax,
    String? clientShortName,
    String? clientCountryCode,
    String? clientGlCode,
    String? clientFiscalYear,
    String? clientParentCode,
    String? clientChildCode,
    bool? clientStatus,
    bool? clientVendor,
  }) async {
    try {
      // final url = '$API_BASE_URL/Entity/addnew';
      // final resp = await http
      //     .post(
      //       Uri.parse(url),
      //       headers: getHeaders(),
      //       body: jsonEncode({
      //         'entityCode': clientCode,
      //         'entityName': clientName,
      //         'entitySuitNo': clientSuitNo,
      //         'entitySteetNO': clientSteetNO,
      //         'entityPostalCode': clientPostalCode,
      //         'entityLegalName': clientLegalName,
      //         'entityTown': clientTown,
      //         'entityProvince': clientProvince,
      //         'entityCountry': clientCountry,
      //         'entityEmail': clientEmail,
      //         'entityPhone': clientPhone,
      //         'entityIndustryCode': clientIndustryCode,
      //         'entityFax': clientFax,
      //         'entityShortName': clientShortName,
      //         'entityCountryCode': clientCountryCode,
      //         'entityGlCode': clientGlCode,
      //         'entityFiscalYear': clientFiscalYear,
      //         'entityParentCode': clientParentCode,
      //         'entityChildCode': clientChildCode,
      //         'entityStatus': clientStatus,
      //         'entityVendor': clientVendor,
      //       }),
      //     )
      //     .timeout(Duration(seconds: 30));

      final response = await ApiClient().dio.post(
        'Entity/addnew',
        data: {
          'entityCode': clientCode,
          'entityName': clientName,
          'entitySuitNo': clientSuitNo,
          'entitySteetNO': clientSteetNO,
          'entityPostalCode': clientPostalCode,
          'entityLegalName': clientLegalName,
          'entityTown': clientTown,
          'entityProvince': clientProvince,
          'entityCountry': clientCountry,
          'entityEmail': clientEmail,
          'entityPhone': clientPhone,
          'entityIndustryCode': clientIndustryCode,
          'entityFax': clientFax,
          'entityShortName': clientShortName,
          'entityCountryCode': clientCountryCode,
          'entityGlCode': clientGlCode,
          'entityFiscalYear': clientFiscalYear,
          'entityParentCode': clientParentCode,
          'entityChildCode': clientChildCode,
          'entityStatus': clientStatus,
          'entityVendor': clientVendor,
        },
        options: Options(receiveTimeout: Duration(seconds: 30)),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        final error = response.data;
        return {
          'success': false,
          'error':
              error['error'] ??
              'Failed to create the client. Please try again.',
        };
      }
    } catch (e) {
      print('Client Setup error: $e');
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>> addDevice({
    required String deviceName,
    required String deviceIpAddress,
    required String deviceLocation,
    required String devicePort,
    required String deviceMachineNumber,
    required bool isDeviceActive,
    required bool CanReadLogs,
    required String deviceCompanyCode,
  }) async {
    try {
      // final url = '$API_BASE_URL/device/AddNew';
      // final resp = await http
      //     .post(
      //       Uri.parse(url),
      //       headers: getHeaders(),
      //       body: jsonEncode({
      //         'deviceName': deviceName,
      //         'ipAddress': deviceIpAddress,
      //         'portNumber': devicePort,
      //         'location': deviceLocation,
      //         'machineNumber': deviceMachineNumber,
      //         'isActive': isDeviceActive,
      //         'CanReadLogs': CanReadLogs,
      //         'companyCode': deviceCompanyCode,
      //       }),
      //     )
      //     .timeout(Duration(seconds: 30));

      final response = await ApiClient().dio.post(
        'device/AddNew',
        data: {
          'deviceName': deviceName,
          'ipAddress': deviceIpAddress,
          'portNumber': devicePort,
          'location': deviceLocation,
          'machineNumber': deviceMachineNumber,
          'isActive': isDeviceActive,
          'CanReadLogs': CanReadLogs,
          'companyCode': deviceCompanyCode,
        },
        options: Options(receiveTimeout: Duration(seconds: 30)),
      );
      print('my device check ${response.data}');
      if (response.statusCode == 200) {
        return response.data;
      } else {
        final error = response.data;
        return {
          'success': false,
          'error':
              error['error'] ??
              'Failed to create the device. Please try again.',
        };
      }
    } catch (e) {
      print(' Device Setup error: $e');
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>> editDevice({
    required String deviceId,
    required String deviceName,
    required String deviceIpAddress,
    required String deviceLocation,
    required String devicePort,
    required String deviceMachineNumber,
    required bool isDeviceActive,
    required bool CanReadLogs,
    required String deviceCompanyCode,
    String? deviceStatus,
  }) async {
    try {
      // final url = '$API_BASE_URL/device/Update';

      // final resp = await http
      //     .post(
      //       Uri.parse(url),
      //       headers: getHeaders(),
      //       body: jsonEncode({
      //         'deviceId': deviceId,
      //         'deviceName': deviceName,
      //         'ipAddress': deviceIpAddress,
      //         'portNumber': devicePort,
      //         'location': deviceLocation,
      //         'machineNumber': deviceMachineNumber,
      //         'status': deviceStatus,
      //         'isActive': isDeviceActive,
      //         'CanReadLogs': CanReadLogs,
      //         'companyCode': deviceCompanyCode,
      //       }),
      //     )
      //     .timeout(const Duration(seconds: 30));

      final response = await ApiClient().dio.post(
        'device/Update',
        data: {
          'deviceId': deviceId,
          'deviceName': deviceName,
          'ipAddress': deviceIpAddress,
          'portNumber': devicePort,
          'location': deviceLocation,
          'machineNumber': deviceMachineNumber,
          'status': deviceStatus,
          'isActive': isDeviceActive,
          'CanReadLogs': CanReadLogs,
          'companyCode': deviceCompanyCode,
        },
        options: Options(receiveTimeout: Duration(seconds: 30)),
      );

      print('🛠 Edit device response: ${response.data}');

      if (response.statusCode == 200) {
        return response.data;
      } else {
        final error = response.data;
        return {
          'success': false,
          'error': error['error'] ?? 'Failed to update the device.',
        };
      }
    } catch (e) {
      print('❌ Device Update error: $e');
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // NEW: Get Team Tasks
  static Future<List<TaskModel>> getTeamTasks(String teamLeadId) async {
    try {
      print('📊 Fetching team tasks for: $teamLeadId');
      // final response = await http
      //     .get(
      //       Uri.parse('$API_BASE_URL/task/team/$teamLeadId'),
      //       headers: getHeaders(),
      //     )
      //     .timeout(Duration(seconds: 10));

      final response = await ApiClient().dio.get(
        'task/team/$teamLeadId',
        options: Options(receiveTimeout: Duration(seconds: 10)),
      );

      print('📡 Team tasks response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(
          response.data,
        );

        return data.map(TaskModel.fromJson).toList();
      }

      return [];
    } catch (e) {
      print('Get team tasks error: $e');
      return [];
    }
  }

  // Chart
  static Future<Chart?> chart({
    required String employeeId,
    required DateTime endDate,
    required DateTime dateTime,
  }) async {
    try {
      // final queryParams = {
      //   'EmpCode': employeeId,
      //   'endDate': endDate.toIso8601String(),
      //   'dateTime': dateTime.toIso8601String(),
      // };

      // final uri = Uri.parse(
      //   '$API_BASE_URL/attendance/ontimeandlaterecords',
      // ).replace(queryParameters: queryParams);

      // final response = await http
      //     .get(uri, headers: getHeaders())
      //     .timeout(const Duration(seconds: 90));

      final response = await ApiClient().dio.get(
        'attendance/ontimeandlaterecords',
        queryParameters: {
          'EmpCode': employeeId,
          'endDate': endDate.toIso8601String(),
          'dateTime': dateTime.toIso8601String(),
        },
        options: Options(receiveTimeout: Duration(seconds: 90)),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        return Chart.fromJson(data);
      } else {
        return null;
      }
    } catch (e) {
      print('Chart API error: $e');
      return null;
    }
  }

  static Future<List<UserDevices>> fetchDeviceRegistrationRequests() async {
    // final response = await http
    //     .get(
    //       Uri.parse('$API_BASE_URL/employee/requestsfornewuserdevices'),
    //       headers: getHeaders(),
    //     )
    //     .timeout(Duration(seconds: 10));
    final response = await ApiClient().dio.get(
      'employee/requestsfornewuserdevices',
      options: Options(receiveTimeout: Duration(seconds: 10)),
    );
    if (response.statusCode != 200) {
      throw Exception("Failed to load requests");
    }

    final List data = response.data;
    return data.map((e) => UserDevices.fromJson(e)).toList();
  }

  static Future<void> handleDeviceRegistrationRequest(
    String requestId,
    bool approve, {
    String? reason,
  }) async {
    // final response = await http
    //     .post(
    //       Uri.parse('$API_BASE_URL/employee/approveusernewdevice'),
    //       headers: getHeaders(),
    //       body: jsonEncode({
    //         "requestId": requestId,
    //         "isApprove": approve,
    //         "reason": reason,
    //       }),
    //     )
    //     .timeout(Duration(seconds: 10));
    final response = await ApiClient().dio.post(
      'employee/approveusernewdevice',
      data: {"requestId": requestId, "isApprove": approve, "reason": reason},
      options: Options(receiveTimeout: Duration(seconds: 10)),
    );
    if (response.statusCode != 200) {
      throw Exception("Failed to process request");
    }
  }
}

class TaskSummaryResponse {
  final int ToDoCount;
  final int InProgressCount;
  final int CompleteCount;

  TaskSummaryResponse({
    required this.ToDoCount,
    required this.InProgressCount,
    required this.CompleteCount,
  });

  factory TaskSummaryResponse.fromJson(Map<String, dynamic> json) {
    return TaskSummaryResponse(
      ToDoCount: json['toDoCount'],
      InProgressCount: json['inProgressCount'],
      CompleteCount: json['completeCount'],
    );
  }
}
