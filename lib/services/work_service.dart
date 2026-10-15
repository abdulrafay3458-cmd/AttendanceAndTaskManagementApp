import 'dart:io';
import 'package:attendance_app/services/ApiClient.dart';
import 'package:dio/dio.dart';
import '../models/work_models.dart';

class WorkException implements Exception {
  final String message;
  WorkException(this.message);
  @override
  String toString() => message;
}

class WorkService {
  final Dio _dio;
  WorkService(this._dio);

  String _base(String id) => 'api/assignments/$id';

  dynamic _unwrap(Response r) {
    final body = r.data;
    if (body is Map<String, dynamic> && body.containsKey('data'))
      return body['data'];
    return body;
  }

  Future<T> _call<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['message'] != null)
          ? data['message'].toString()
          : (e.type == DioExceptionType.connectionError
                ? 'No connection to server.'
                : 'Something went wrong (${e.response?.statusCode ?? 'network'}).');
      throw WorkException(msg);
    }
  }

  /// tab: 'inprogress' | 'completed'
  Future<List<AssignmentItem>> getMyAssignments(
    String employeeId,
    String tab,
  ) => _call(() async {
    final r = await ApiClient().dio.get(
      'work/getEmployeeTaskById',
      queryParameters: {'employeeId': employeeId, 'status': tab},
    );
    return (_unwrap(r) as List)
        .map((e) => AssignmentItem.fromJson(e as Map<String, dynamic>))
        .toList();
  });

  Future<WorkState> getState(String id, String empId) => _call(() async {
    final r = await _dio.get(
      'work/work-state',
      queryParameters: {'assignmentId': id, 'employeeId': empId},
    );
    return WorkState.fromJson(_unwrap(r) as Map<String, dynamic>);
  });

  Future<WorkState> startSession(
    String id,
    String empId,
    double lat,
    double lng,
  ) => _call(() async {
    final r = await _dio.post(
      'work/sessions/start',
      queryParameters: {
        'assignmentId': id,
        'empId': empId,
        'latitude': lat,
        'longitude': lng,
      },
    );
    return WorkState.fromJson(_unwrap(r) as Map<String, dynamic>);
  });
  // Future<WorkState> startSession(String id, String empId) => _call(() async {
  //   final r = await _dio.post(
  //     'work/sessions/start',
  //     queryParameters: {
  //       'assignmentId': id,
  //       'empId': empId,
  //     },
  //   );
  //   return WorkState.fromJson(_unwrap(r) as Map<String, dynamic>);
  // });

  Future<List<AssignmentItem>> stopSession(String id, String empId) =>
      _call(() async {
        final r = await _dio.post(
          'work/sessions/stop',
          queryParameters: {'assignmentId': id, 'employeeId': empId},
        );
        final data = _unwrap(r);
        return (data as List)
            .map((e) => AssignmentItem.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  /// [workDate] must be the server-provided WorkState.todayDate (yyyy-MM-dd), not the phone's date.
  Future<void> saveDailySummary(
    String id,
    String empId,
    String workDate,
    String summary,
    String remarks,
  ) => _call(() async {
    await _dio.put(
      'work/daily-summary',
      queryParameters: {'assignmentId': id, 'employeeId': empId},
      data: {
        'workDate': workDate,
        'summary': summary,
        'remarks': remarks.isEmpty ? null : remarks,
      },
    );
  });

  /// Sends raw GPS + photo. The server calculates the distance and decides the result.
  Future<void> validateSite(
    String id,
    String empId,
    double latitude,
    double longitude,
    File snapshot,
  ) => _call(() async {
    final form = FormData.fromMap({
      'latitude': latitude,
      'longitude': longitude,
      'snapshot': await MultipartFile.fromFile(
        snapshot.path,
        filename: snapshot.path.split('/').last,
      ),
    });

    await _dio.post(
      'work/site-validation',
      queryParameters: {'assignmentId': id, 'employeeId': empId},
      data: form,
    );
  });

  Future<void> complete(
    String id,
    String empId,
    String finalSummary,
    String remarks,
    File? photo,
  ) => _call(() async {
    final form = FormData.fromMap({
      'finalSummary': finalSummary,
      'remarks': remarks.isEmpty ? null : remarks,
      if (photo != null)
        'snapshot': await MultipartFile.fromFile(
          photo.path,
          filename: 'completion.jpg',
        ),
    });

    await _dio.post(
      'work/complete',
      queryParameters: {'assignmentId': id, 'employeeId': empId},
      data: form,
    );
  });
}
