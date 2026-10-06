import 'dart:async';

import 'package:attendance_app/login.dart';
import 'package:attendance_app/main.dart';
import 'package:attendance_app/services/apiservice.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();

  factory ApiClient() => _instance;

  late Dio dio;

  bool _isRefreshing = false;
  Completer<bool>? _refreshCompleter;

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: API_BASE_URL,
        receiveTimeout: const Duration(seconds: 20),
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Always read the token fresh, at request time.
          if (options.extra['skipAuth'] == true) {
            // Don't clobber a request-specific Content-Type
            // (e.g. multipart/form-data).
            options.headers.putIfAbsent(
              'Content-Type',
              () => 'application/json',
            );
            return handler.next(options);
          }

          final authToken = ApiService.authToken;
          final deviceHash = ApiService.deviceHash;

          if (authToken != null && authToken.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $authToken';
          }

          if (deviceHash != null && deviceHash.isNotEmpty) {
            options.headers['device_Hash'] = deviceHash;
          }

          // Don't clobber a request-specific Content-Type.
          options.headers.putIfAbsent(
            'Content-Type',
            () => 'application/json',
          );

          return handler.next(options);
        },

        onError: (e, handler) async {
          final is401 = e.response?.statusCode == 401;
          final skipAuth = e.requestOptions.extra['skipAuth'] == true;
          final alreadyRetried =
              e.requestOptions.extra['retried'] == true;

          // Not a 401, public request, or already retried — give up.
          if (!is401 || skipAuth || alreadyRetried) {
            return handler.next(e);
          }

          try {
            final refreshSuccessful = await _refreshToken();
            if (!refreshSuccessful) {
              return handler.next(e);
            }

            final requestOptions = e.requestOptions;

            // Mark so we can't retry forever.
            requestOptions.extra['retried'] = true;

            // Rebuild headers with the freshly stored token.
            requestOptions.headers.remove('Authorization');
            final newToken = ApiService.authToken;
            if (newToken != null && newToken.isNotEmpty) {
              requestOptions.headers['Authorization'] =
                  'Bearer $newToken';
            }

            print(
              '🔁 Retrying request: ${requestOptions.method} '
              '${requestOptions.path}',
            );

            final response = await dio.fetch(requestOptions);
            return handler.resolve(response);
          } catch (error) {
            print('❌ Retry after refresh failed: $error');
            return handler.next(e);
          }
        },
      ),
    );
  }

  /// Builds the headers used for **external** callers.
  /// (The interceptor no longer relies on this — it reads the token
  /// directly, so a request made right after login always has the
  /// current token.)
  static Map<String, String> getHeaders() {
    final authToken = ApiService.authToken;
    final deviceHash = ApiService.deviceHash;

    return {
      'Content-Type': 'application/json',
      if (authToken != null && authToken.isNotEmpty)
        'Authorization': 'Bearer $authToken',
      if (deviceHash != null && deviceHash.isNotEmpty)
        'device_Hash': deviceHash,
    };
  }

  Future<bool> _refreshToken() async {
    // Deduplicate concurrent refresh attempts.
    if (_isRefreshing) {
      print('⏳ Token refresh already in progress. Waiting...');
      return await _refreshCompleter!.future;
    }

    _isRefreshing = true;
    _refreshCompleter = Completer<bool>();

    try {
      print('🔄 Requesting refresh token...');

      final refresh = await ApiService.RequestRefreshToken();

      if (refresh == true) {
        print('✅ Token refreshed successfully.');
        _refreshCompleter!.complete(true);
        return true;
      }

      print('❌ Refresh token failed.');
      await _handleRefreshFailure();
      _refreshCompleter!.complete(false);
      return false;
    } catch (error) {
      print('❌ Refresh token error: $error');
      await _handleRefreshFailure();
      _refreshCompleter!.complete(false);
      return false;
    } finally {
      _isRefreshing = false;
      _refreshCompleter = null;
    }
  }

  Future<void> _handleRefreshFailure() async {
    print('🔓 Refresh failed. Clearing credentials and signing out.');

    await ApiService.clearCredentials();

    if (navigatorKey.currentState?.mounted == true) {
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => LoginScreen()),
        (route) => false,
      );
    }
  }
}