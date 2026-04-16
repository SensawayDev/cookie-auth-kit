import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cookie_auth_client/cookie_auth_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CookieAuthDio', () {
    test('sets and clears bearer token', () {
      final authDio = CookieAuthDio(Dio());

      authDio.setAccessToken(const AccessToken(value: 'abc123'));

      expect(authDio.hasToken, isTrue);
      expect(authDio.bearerToken, 'abc123');

      authDio.clearAccessToken();

      expect(authDio.hasToken, isFalse);
      expect(authDio.bearerToken, isNull);
    });

    test('refreshes and retries one failed request', () async {
      var protectedCallCount = 0;
      var refreshCallCount = 0;
      final adapter = _StubHttpClientAdapter((options) async {
        if (options.path == '/protected') {
          protectedCallCount += 1;
          if (protectedCallCount == 1) {
            return const _StubResponse(statusCode: 401, body: {'error': 'no'});
          }

          expect(options.headers['Authorization'], 'Bearer fresh-access');
          return const _StubResponse(statusCode: 200, body: {'ok': true});
        }

        fail('Unexpected request: ${options.method} ${options.path}');
      });
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api'));
      dio.httpClientAdapter = adapter;
      final authDio = CookieAuthDio(dio);
      authDio.configureAuthHandlers(
        onRefreshAccessToken: () async {
          refreshCallCount += 1;
          return const AccessToken(value: 'fresh-access');
        },
        onUnauthorized: () async {},
      );

      final response = await dio.get('/protected');

      expect(response.data, {'ok': true});
      expect(protectedCallCount, 2);
      expect(refreshCallCount, 1);
    });

    test('adds CSRF header to credentialed requests', () async {
      final adapter = _StubHttpClientAdapter((options) async {
        expect(options.headers['x-csrf-token'], 'csrf-token');
        return const _StubResponse(statusCode: 200, body: {'ok': true});
      });
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api'));
      dio.httpClientAdapter = adapter;
      final authDio = CookieAuthDio(dio, csrfTokenReader: (_) => 'csrf-token');
      authDio.configureAuthHandlers(
        onRefreshAccessToken: () async => null,
        onUnauthorized: () async {},
      );

      await dio.post(
        '/auth/refresh',
        options: Options(extra: cookieAuthWithCredentials),
      );

      expect(adapter.requestPaths, ['/auth/refresh']);
    });

    test('does not refresh auth endpoint failures', () async {
      var refreshCallCount = 0;
      final adapter = _StubHttpClientAdapter((options) async {
        return const _StubResponse(statusCode: 401, body: {'error': 'no'});
      });
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api'));
      dio.httpClientAdapter = adapter;
      final authDio = CookieAuthDio(dio);
      authDio.configureAuthHandlers(
        onRefreshAccessToken: () async {
          refreshCallCount += 1;
          return const AccessToken(value: 'fresh-access');
        },
        onUnauthorized: () async {},
      );

      await expectLater(dio.post('/auth/login'), throwsA(isA<DioException>()));
      expect(refreshCallCount, 0);
    });

    test('calls onUnauthorized when refresh fails', () async {
      var unauthorizedCallCount = 0;
      final adapter = _StubHttpClientAdapter((options) async {
        return const _StubResponse(statusCode: 401, body: {'error': 'no'});
      });
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api'));
      dio.httpClientAdapter = adapter;
      final authDio = CookieAuthDio(dio);
      authDio.configureAuthHandlers(
        onRefreshAccessToken: () async => null,
        onUnauthorized: () async => unauthorizedCallCount += 1,
      );

      await expectLater(dio.get('/protected'), throwsA(isA<DioException>()));
      expect(unauthorizedCallCount, 1);
    });
  });

  group('DioCookieAuthApi', () {
    test('sends cookie credentials for refresh and logout', () async {
      final adapter = _StubHttpClientAdapter((options) async {
        expect(options.extra['withCredentials'], isTrue);
        expect(options.queryParameters, isEmpty);

        if (options.path == '/auth/refresh') {
          return const _StubResponse(
            statusCode: 200,
            body: {'access_token': 'fresh-access', 'token_type': 'bearer'},
          );
        }
        if (options.path == '/auth/logout') {
          return const _StubResponse(statusCode: 200, body: {'status': 'ok'});
        }

        fail('Unexpected request: ${options.method} ${options.path}');
      });
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api'));
      dio.httpClientAdapter = adapter;
      final authApi = DioCookieAuthApi(
        dio,
        csrfTokenReader: (_) => 'csrf-token',
      );

      final token = await authApi.refresh();
      await authApi.logout();

      expect(token.value, 'fresh-access');
      expect(adapter.requestPaths, ['/auth/refresh', '/auth/logout']);
      for (final request in adapter.requests) {
        expect(request.headers['x-csrf-token'], 'csrf-token');
      }
    });
  });
}

class _StubResponse {
  const _StubResponse({required this.statusCode, required this.body});

  final int statusCode;
  final Object body;
}

class _StubHttpClientAdapter implements HttpClientAdapter {
  _StubHttpClientAdapter(this._handler);

  final Future<_StubResponse> Function(RequestOptions options) _handler;
  final List<RequestOptions> requests = [];

  List<String> get requestPaths =>
      requests.map((request) => request.path).toList();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final response = await _handler(options);
    return ResponseBody.fromString(
      jsonEncode(response.body),
      response.statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
