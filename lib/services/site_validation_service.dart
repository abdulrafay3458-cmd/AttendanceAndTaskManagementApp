// lib/services/site_validation_service.dart
// Pass the same configured Dio your other services use (base URL + auth interceptor).
// Only image + latitude + longitude are sent. The employee id comes from the token on the server.

import 'dart:io';
import 'package:dio/dio.dart';
import '../models/site_validation_models.dart';

/// Carries the server's rule message (face failed, outside site, expired...) to the UI.
class SiteValidationException implements Exception {
  final String message;
  SiteValidationException(this.message);
  @override
  String toString() => message;
}

class SiteValidationService {
  final Dio _dio;
  SiteValidationService(this._dio);

  /// Pass ApiClient().dio. Its baseUrl, Bearer token, device_Hash header and 401 refresh are reused.
  /// If API_BASE_URL already ends with "/api", the "api/" prefix is dropped automatically.
  String get _prefix =>
      _dio.options.baseUrl.replaceAll(RegExp(r'/+$'), '').toLowerCase().endsWith('/api') ? '' : 'api/';

  dynamic _unwrap(Response r) {
    final body = r.data;
    if (body is Map<String, dynamic> && body.containsKey('data')) return body['data'];
    return body;
  }

  Future<T> _call<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['message'] != null)
          ? data['message'].toString()
          : (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout
              ? 'No connection to the server. Check your internet and try again.'
              : 'Something went wrong (${e.response?.statusCode ?? 'network'}).');
      throw SiteValidationException(msg);
    }
  }

  Future<List<SiteValidationRequest>> getPending() => _call(() async {
        final r = await _dio.get('${_prefix}site-validations/pending');
        return (_unwrap(r) as List)
            .map((e) => SiteValidationRequest.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  /// Team Head only: expired / failed / late validations for the people in their team.
  /// Returns an empty list for anyone who is not a Team Head.
  Future<List<SiteValidationRequest>> getTeamAlerts({int days = 7}) => _call(() async {
        final r = await _dio.get('${_prefix}site-validations/team-alerts',
            queryParameters: {'days': days});
        return (_unwrap(r) as List)
            .map((e) => SiteValidationRequest.fromJson(e as Map<String, dynamic>))
            .toList();
      });
    

  Future<SiteValidationRequest> getById(String id) => _call(() async {
        final r = await _dio.get('${_prefix}site-validations/$id');
        return SiteValidationRequest.fromJson(_unwrap(r) as Map<String, dynamic>);
      });

  /// Success returns the result. Any rule failure (face, distance, expired, wrong owner...)
  /// throws a SiteValidationException carrying the server's message.
  Future<SiteValidationResult> validate(String id, double lat, double lng, File photo) => _call(() async {
        final form = FormData.fromMap({
          'latitude': lat,
          'longitude': lng,
          'snapshot': await MultipartFile.fromFile(photo.path, filename: 'presence.jpg'),
        });
        final r = await _dio.post(
          '${_prefix}site-validations/$id/validate',
          data: form,
          options: Options(contentType: 'multipart/form-data'),
        );
        return SiteValidationResult.fromJson(_unwrap(r) as Map<String, dynamic>);
      });
}
