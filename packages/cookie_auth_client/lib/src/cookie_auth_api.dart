import 'package:dio/dio.dart';

import 'access_token.dart';
import 'csrf_cookie_reader.dart' as csrf_cookie_reader;

const cookieAuthWithCredentials = {'withCredentials': true};

typedef AccessTokenParser = AccessToken Function(Object? data);
typedef CsrfTokenReader = String? Function(String cookieName);

abstract class CookieAuthApi {
  Future<AccessToken> login({
    required String username,
    required String password,
  });

  Future<AccessToken> refresh();

  Future<void> logout();
}

class DioCookieAuthApi implements CookieAuthApi {
  DioCookieAuthApi(
    this.dio, {
    this.loginPath = '/auth/login',
    this.refreshPath = '/auth/refresh',
    this.logoutPath = '/auth/logout',
    this.usernameField = 'username',
    this.passwordField = 'password',
    this.parseAccessToken = defaultAccessTokenParser,
    this.csrfCookieName = 'cookie_auth_csrf',
    this.csrfHeaderName = 'x-csrf-token',
    CsrfTokenReader? csrfTokenReader,
  }) : _csrfTokenReader = csrfTokenReader ?? csrf_cookie_reader.readCookieValue;

  final Dio dio;
  final String loginPath;
  final String refreshPath;
  final String logoutPath;
  final String usernameField;
  final String passwordField;
  final AccessTokenParser parseAccessToken;
  final String csrfCookieName;
  final String csrfHeaderName;
  final CsrfTokenReader _csrfTokenReader;

  @override
  Future<AccessToken> login({
    required String username,
    required String password,
  }) async {
    final response = await dio.post(
      loginPath,
      data: FormData.fromMap({
        usernameField: username,
        passwordField: password,
      }),
      options: _credentialedOptions(),
    );
    return parseAccessToken(response.data);
  }

  @override
  Future<AccessToken> refresh() async {
    final response = await dio.post(
      refreshPath,
      options: _credentialedOptions(),
    );
    return parseAccessToken(response.data);
  }

  @override
  Future<void> logout() async {
    await dio.post(logoutPath, options: _credentialedOptions());
  }

  Options _credentialedOptions() {
    return Options(extra: cookieAuthWithCredentials, headers: _csrfHeaders());
  }

  Map<String, String>? _csrfHeaders() {
    final csrfToken = _csrfTokenReader(csrfCookieName);
    if (csrfToken == null || csrfToken.trim().isEmpty) {
      return null;
    }
    return {csrfHeaderName: csrfToken};
  }
}

AccessToken defaultAccessTokenParser(Object? data) {
  if (data is! Map) {
    throw ArgumentError.value(data, 'data', 'Expected token response map');
  }

  final accessToken = data['access_token'];
  if (accessToken is! String || accessToken.trim().isEmpty) {
    throw ArgumentError.value(data, 'data', 'Missing access_token');
  }

  final tokenType = data['token_type'];
  return AccessToken(
    value: accessToken,
    tokenType: tokenType is String && tokenType.isNotEmpty
        ? tokenType
        : 'bearer',
  );
}
