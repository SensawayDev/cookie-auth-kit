import 'dart:async';

import 'package:cookie_auth_client/cookie_auth_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CookieAuthController', () {
    test('login stores access token and loads current user', () async {
      var legacyCleared = false;
      final dio = Dio();
      final authApi = _FakeCookieAuthApi(
        onLogin: ({required username, required password}) async {
          expect(username, 'name@example.com');
          expect(password, 'secret');
          return const AccessToken(value: 'login-access');
        },
      );
      final controller = CookieAuthController<_User>(
        authApi: authApi,
        authDio: CookieAuthDio(dio),
        loadCurrentUser: () async => const _User('user-1'),
        clearLegacySession: () async => legacyCleared = true,
      );

      await controller.login('name@example.com', 'secret');

      expect(controller.isAuthenticated, isTrue);
      expect(controller.currentUser?.id, 'user-1');
      expect(controller.authDio.bearerToken, 'login-access');
      expect(legacyCleared, isTrue);
    });

    test('restoreSession authenticates quietly from refresh', () async {
      final controller = CookieAuthController<_User>(
        authApi: _FakeCookieAuthApi(
          onRefresh: () async => const AccessToken(value: 'restored-access'),
        ),
        authDio: CookieAuthDio(Dio()),
        loadCurrentUser: () async => const _User('user-1'),
      );

      await controller.restoreSession();

      expect(controller.isRestoringSession, isFalse);
      expect(controller.isAuthenticated, isTrue);
      expect(controller.authDio.bearerToken, 'restored-access');
    });

    test('restoreSession failure stays logged out quietly', () async {
      final controller = CookieAuthController<_User>(
        authApi: _FakeCookieAuthApi(
          onRefresh: () async => throw Exception('expired'),
        ),
        authDio: CookieAuthDio(Dio()),
        loadCurrentUser: () async => const _User('user-1'),
      );

      await controller.restoreSession();

      expect(controller.isRestoringSession, isFalse);
      expect(controller.isAuthenticated, isFalse);
      expect(controller.consumeNotice(), isNull);
    });

    test('logout clears local state even when backend logout fails', () async {
      final controller = CookieAuthController<_User>(
        authApi: _FakeCookieAuthApi(
          onLogin: ({required username, required password}) async =>
              const AccessToken(value: 'login-access'),
          onLogout: () async => throw Exception('network down'),
        ),
        authDio: CookieAuthDio(Dio()),
        loadCurrentUser: () async => const _User('user-1'),
      );

      await controller.login('name@example.com', 'secret');
      await controller.logout();

      expect(controller.isAuthenticated, isFalse);
      expect(controller.authDio.hasToken, isFalse);
    });

    test('refreshAccessToken shares one in-flight refresh request', () async {
      final completer = Completer<AccessToken>();
      var refreshCallCount = 0;
      final controller = CookieAuthController<_User>(
        authApi: _FakeCookieAuthApi(
          onRefresh: () {
            refreshCallCount += 1;
            return completer.future;
          },
        ),
        authDio: CookieAuthDio(Dio()),
        loadCurrentUser: () async => const _User('user-1'),
      );

      final first = controller.refreshAccessToken();
      final second = controller.refreshAccessToken();
      completer.complete(const AccessToken(value: 'refreshed-access'));

      expect((await first)?.value, 'refreshed-access');
      expect((await second)?.value, 'refreshed-access');
      expect(refreshCallCount, 1);
      expect(controller.authDio.bearerToken, 'refreshed-access');
    });

    test('expireSession clears state and exposes a notice', () async {
      final controller = CookieAuthController<_User>(
        authApi: _FakeCookieAuthApi(
          onLogin: ({required username, required password}) async =>
              const AccessToken(value: 'login-access'),
        ),
        authDio: CookieAuthDio(Dio()),
        loadCurrentUser: () async => const _User('user-1'),
      );

      await controller.login('name@example.com', 'secret');
      await controller.expireSession();

      expect(controller.isAuthenticated, isFalse);
      expect(controller.consumeNotice(), AuthNotice.sessionExpired);
      expect(controller.consumeNotice(), isNull);
    });
  });
}

class _User {
  const _User(this.id);

  final String id;
}

class _FakeCookieAuthApi implements CookieAuthApi {
  _FakeCookieAuthApi({this.onLogin, this.onRefresh, this.onLogout});

  final Future<AccessToken> Function({
    required String username,
    required String password,
  })?
  onLogin;
  final Future<AccessToken> Function()? onRefresh;
  final Future<void> Function()? onLogout;

  @override
  Future<AccessToken> login({
    required String username,
    required String password,
  }) {
    final handler = onLogin;
    if (handler == null) {
      throw UnimplementedError('login was not expected');
    }
    return handler(username: username, password: password);
  }

  @override
  Future<AccessToken> refresh() {
    final handler = onRefresh;
    if (handler == null) {
      throw UnimplementedError('refresh was not expected');
    }
    return handler();
  }

  @override
  Future<void> logout() {
    final handler = onLogout;
    if (handler == null) {
      return Future.value();
    }
    return handler();
  }
}
