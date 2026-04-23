import 'package:cookie_auth_client/cookie_auth_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('authFailureFromError', () {
    test('maps invalid credentials from backend code', () {
      final failure = authFailureFromError(
        _dioException(
          statusCode: 401,
          backendCode: 'invalid_credentials',
        ),
      );

      expect(failure.reason, AuthFailureReason.invalidCredentials);
      expect(failure.statusCode, 401);
      expect(failure.backendCode, 'invalid_credentials');
    });

    test('maps expired session codes distinctly from generic 401', () {
      final failure = authFailureFromError(
        _dioException(
          statusCode: 401,
          backendCode: 'expired_refresh_token',
        ),
      );

      expect(failure.reason, AuthFailureReason.sessionExpired);
      expect(failure.statusCode, 401);
      expect(failure.backendCode, 'expired_refresh_token');
    });

    test('maps server rejected codes from 403 responses', () {
      final failure = authFailureFromError(
        _dioException(
          statusCode: 403,
          backendCode: 'invalid_csrf_token',
        ),
      );

      expect(failure.reason, AuthFailureReason.serverRejected);
      expect(failure.statusCode, 403);
      expect(failure.backendCode, 'invalid_csrf_token');
    });

    test('falls back to status code when backend code is unavailable', () {
      final forbidden = authFailureFromError(_dioException(statusCode: 403));
      final unauthorized = authFailureFromError(_dioException(statusCode: 401));

      expect(forbidden.reason, AuthFailureReason.serverRejected);
      expect(forbidden.backendCode, isNull);
      expect(unauthorized.reason, AuthFailureReason.invalidCredentials);
      expect(unauthorized.backendCode, isNull);
    });

    test('maps unknown failures to unavailable', () {
      final failure = authFailureFromError(Exception('network down'));

      expect(failure.reason, AuthFailureReason.unavailable);
      expect(failure.statusCode, isNull);
      expect(failure.backendCode, isNull);
    });

    test('returns existing AuthFailure unchanged', () {
      const failure = AuthFailure(
        AuthFailureReason.sessionExpired,
        statusCode: 401,
        backendCode: 'expired_refresh_token',
      );

      expect(identical(authFailureFromError(failure), failure), isTrue);
    });
  });
}

DioException _dioException({
  required int statusCode,
  String? backendCode,
}) {
  final headers = <String, List<String>>{};
  if (backendCode != null) {
    headers[cookieAuthErrorCodeHeader] = [backendCode];
  }

  return DioException.badResponse(
    statusCode: statusCode,
    requestOptions: RequestOptions(path: '/auth/login'),
    response: Response<dynamic>(
      requestOptions: RequestOptions(path: '/auth/login'),
      statusCode: statusCode,
      headers: Headers.fromMap(headers),
    ),
  );
}
