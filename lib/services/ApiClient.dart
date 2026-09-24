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
          if (options.extra['skipAuth'] == true) {
            options.headers['Content-Type'] = 'application/json';
            return handler.next(options);
          }

          options.headers.addAll(getHeaders());

          return handler.next(options);
        },

        onError: (e, handler) async {
          final is401 = e.response?.statusCode == 401;
          final skipAuth = e.requestOptions.extra['skipAuth'] == true;
          final alreadyRetried =
              e.requestOptions.extra['retried'] == true;

          // Not a 401, or this is a public request.
          if (!is401 || skipAuth) {
            return handler.next(e);
          }

          // Don't retry the same request forever.
          if (alreadyRetried) {
            return handler.next(e);
          }

          try {
            final refreshSuccessful = await _refreshToken();

            if (!refreshSuccessful) {
              return handler.next(e);
            }

            final requestOptions = e.requestOptions;

            // Mark this request so it cannot retry indefinitely.
            requestOptions.extra['retried'] = true;

            // Get the newly refreshed token.
            requestOptions.headers.addAll(getHeaders());

            print(
              'Retrying request: ${requestOptions.method} '
              '${requestOptions.path}',
            );

            final response = await dio.fetch(requestOptions);

            return handler.resolve(response);
          } catch (error) {
            return handler.next(e);
          }
        },
      ),
    );
  }

  static Map<String, String> getHeaders() {
    final authToken = ApiService.authToken;
    final deviceHash = ApiService.deviceHash;

    return {
      'Content-Type': 'application/json',
      if (authToken != null)
        'Authorization': 'Bearer $authToken',
      if (deviceHash != null)
        'device_Hash': deviceHash,
    };
  }

  Future<bool> _refreshToken() async {
    // Another request is already refreshing.
    // Wait for that refresh to finish.
    if (_isRefreshing) {
      print('Token refresh already in progress. Waiting...');

      return await _refreshCompleter!.future;
    }

    _isRefreshing = true;
    _refreshCompleter = Completer<bool>();

    try {
      print('Requesting refresh token...');

      final refresh = await ApiService.RequestRefreshToken();

      if (refresh == true) {
        print('Token refreshed successfully.');

        _refreshCompleter!.complete(true);

        return true;
      }

      print('Refresh token failed.');

      await _handleRefreshFailure();

      _refreshCompleter!.complete(false);

      return false;
    } catch (error) {
      print('Refresh token error: $error');

      await _handleRefreshFailure();

      _refreshCompleter!.complete(false);

      return false;
    } finally {
      _isRefreshing = false;
      _refreshCompleter = null;
    }
  }

  Future<void> _handleRefreshFailure() async {
    print('Refresh token not found. Clearing credentials.');

    await ApiService.clearCredentials();

    if (navigatorKey.currentState?.mounted == true) {
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => LoginScreen(),
        ),
        (route) => false,
      );
    }
  }
}
