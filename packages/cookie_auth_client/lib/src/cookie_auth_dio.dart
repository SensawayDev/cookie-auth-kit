import 'package:dio/dio.dart';

import 'access_token.dart';
import 'cookie_auth_api.dart';
import 'csrf_cookie_reader.dart' as csrf_cookie_reader;

const _authRetryKey = 'cookie_auth_retry';

class CookieAuthDio {
  CookieAuthDio(
    this.dio, {
    this.csrfCookieName = 'cookie_auth_csrf',
    this.csrfHeaderName = 'x-csrf-token',
    CsrfTokenReader? csrfTokenReader,
  }) : _csrfTokenReader = csrfTokenReader ?? csrf_cookie_reader.readCookieValue;

  final Dio dio;
  final String csrfCookieName;
  final String csrfHeaderName;
  final CsrfTokenReader _csrfTokenReader;
  Future<AccessToken?> Function()? _refreshAccessToken;
  Future<void> Function()? _onUnauthorized;
  Set<String> _authPaths = const {
    '/auth/login',
    '/auth/register',
    '/auth/refresh',
    '/auth/logout',
  };
  bool _isConfigured = false;

  String? get bearerToken {
    final value = dio.options.headers['Authorization'];
    if (value is! String || value.isEmpty) {
      return null;
    }

    const prefix = 'Bearer ';
    return value.startsWith(prefix) ? value.substring(prefix.length) : value;
  }

  bool get hasToken => bearerToken != null;

  void setAccessToken(AccessToken token) {
    dio.options.headers['Authorization'] = 'Bearer ${token.value}';
  }

  void clearAccessToken() {
    dio.options.headers.remove('Authorization');
  }

  void configureAuthHandlers({
    required Future<AccessToken?> Function() onRefreshAccessToken,
    required Future<void> Function() onUnauthorized,
    Set<String> authPaths = const {
      '/auth/login',
      '/auth/register',
      '/auth/refresh',
      '/auth/logout',
    },
  }) {
    _refreshAccessToken = onRefreshAccessToken;
    _onUnauthorized = onUnauthorized;
    _authPaths = authPaths;

    if (_isConfigured) {
      return;
    }

    _isConfigured = true;
    dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: (options, handler) {
          _attachCsrfHeader(options);
          handler.next(options);
        },
        onError: (error, handler) async {
          if (!_shouldAttemptRefresh(error)) {
            handler.next(error);
            return;
          }

          final refreshedToken = await _refreshAccessToken?.call();
          if (refreshedToken == null || refreshedToken.value.trim().isEmpty) {
            await _onUnauthorized?.call();
            handler.next(error);
            return;
          }

          try {
            final response = await _retryRequest(
              error.requestOptions,
              refreshedToken,
            );
            handler.resolve(response);
          } on DioException catch (retryError) {
            handler.next(retryError);
          } catch (_) {
            handler.next(error);
          }
        },
      ),
    );
  }

  bool _shouldAttemptRefresh(DioException error) {
    final requestOptions = error.requestOptions;
    if (error.response?.statusCode != 401) {
      return false;
    }
    if (_refreshAccessToken == null) {
      return false;
    }
    if (requestOptions.extra[_authRetryKey] == true) {
      return false;
    }
    return !_isAuthPath(requestOptions.path);
  }

  bool _isAuthPath(String path) {
    return _authPaths.any(path.startsWith);
  }

  void _attachCsrfHeader(RequestOptions options) {
    if (options.extra['withCredentials'] != true) {
      return;
    }

    final csrfToken = _csrfTokenReader(csrfCookieName);
    if (csrfToken == null || csrfToken.trim().isEmpty) {
      return;
    }
    options.headers[csrfHeaderName] = csrfToken;
  }

  Future<Response<dynamic>> _retryRequest(
    RequestOptions requestOptions,
    AccessToken accessToken,
  ) {
    final headers = Map<String, dynamic>.from(requestOptions.headers)
      ..['Authorization'] = 'Bearer ${accessToken.value}';

    return dio.request<dynamic>(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      cancelToken: requestOptions.cancelToken,
      onReceiveProgress: requestOptions.onReceiveProgress,
      onSendProgress: requestOptions.onSendProgress,
      options: Options(
        method: requestOptions.method,
        headers: headers,
        extra: {...requestOptions.extra, _authRetryKey: true},
        responseType: requestOptions.responseType,
        contentType: requestOptions.contentType,
        followRedirects: requestOptions.followRedirects,
        listFormat: requestOptions.listFormat,
        maxRedirects: requestOptions.maxRedirects,
        receiveDataWhenStatusError: requestOptions.receiveDataWhenStatusError,
        receiveTimeout: requestOptions.receiveTimeout,
        requestEncoder: requestOptions.requestEncoder,
        responseDecoder: requestOptions.responseDecoder,
        sendTimeout: requestOptions.sendTimeout,
        validateStatus: requestOptions.validateStatus,
      ),
    );
  }
}
