import 'package:flutter/foundation.dart';

import 'access_token.dart';
import 'auth_failure.dart';
import 'auth_notice.dart';
import 'cookie_auth_api.dart';
import 'cookie_auth_dio.dart';

typedef LoginFailureMapper = Object Function(Object error);

class CookieAuthController<TUser> extends ChangeNotifier {
  CookieAuthController({
    required CookieAuthApi authApi,
    required CookieAuthDio authDio,
    required Future<TUser> Function() loadCurrentUser,
    Future<void> Function()? clearLegacySession,
    LoginFailureMapper? loginFailureMapper,
    bool restoreSessionOnStart = true,
  }) : _authApi = authApi,
       _authDio = authDio,
       _loadCurrentUser = loadCurrentUser,
       _clearLegacySession = clearLegacySession,
       _loginFailureMapper = loginFailureMapper ?? defaultLoginFailureMapper,
       _isRestoringSession = restoreSessionOnStart {
    _authDio.configureAuthHandlers(
      onRefreshAccessToken: refreshAccessToken,
      onUnauthorized: expireSession,
    );
  }

  final CookieAuthApi _authApi;
  final CookieAuthDio _authDio;
  final Future<TUser> Function() _loadCurrentUser;
  final Future<void> Function()? _clearLegacySession;
  final LoginFailureMapper _loginFailureMapper;

  AccessToken? _token;
  TUser? _currentUser;
  bool _isLoading = false;
  bool _isRestoringSession;
  AuthNotice? _pendingNotice;
  Future<AccessToken?>? _refreshInFlight;

  bool get isAuthenticated => _token != null && _currentUser != null;
  TUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isRestoringSession => _isRestoringSession;
  CookieAuthDio get authDio => _authDio;

  AuthNotice? consumeNotice() {
    final notice = _pendingNotice;
    _pendingNotice = null;
    return notice;
  }

  Future<void> login(String username, String password) async {
    if (_isLoading) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final token = await _authApi.login(
        username: username,
        password: password,
      );
      _authDio.setAccessToken(token);
      final currentUser = await _loadCurrentUser();
      _token = token;
      _currentUser = currentUser;
      _pendingNotice = null;
      await _clearLegacySession?.call();
      onCurrentUserLoaded(currentUser);
    } on Object catch (error) {
      await clearSession(notify: false);
      throw _loginFailureMapper(error);
    } finally {
      _isRestoringSession = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> restoreSession() async {
    if (!_isRestoringSession) {
      return;
    }

    try {
      await _clearLegacySession?.call();
      final token = await _authApi.refresh();
      _authDio.setAccessToken(token);
      final currentUser = await _loadCurrentUser();
      _token = token;
      _currentUser = currentUser;
      _pendingNotice = null;
      onCurrentUserLoaded(currentUser);
    } catch (_) {
      await clearSession(notify: false);
    } finally {
      _isRestoringSession = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await _authApi.logout();
    } catch (_) {
      // Local logout should still complete even if the server request fails.
    } finally {
      await clearSession();
    }
  }

  void updateCurrentUser(TUser user) {
    _currentUser = user;
    onCurrentUserLoaded(user);
    notifyListeners();
  }

  Future<AccessToken?> refreshAccessToken() async {
    final currentRequest = _refreshInFlight;
    if (currentRequest != null) {
      return currentRequest;
    }

    final future = () async {
      try {
        final refreshedToken = await _authApi.refresh();
        _authDio.setAccessToken(refreshedToken);
        _token = refreshedToken;
        return refreshedToken;
      } catch (_) {
        return null;
      } finally {
        _refreshInFlight = null;
      }
    }();

    _refreshInFlight = future;
    return future;
  }

  Future<void> expireSession() async {
    final hadSession = _token != null || _currentUser != null;
    _pendingNotice = AuthNotice.sessionExpired;
    await clearSession(notify: hadSession, keepNotice: true);
  }

  @protected
  Future<void> clearSession({
    bool notify = true,
    bool keepNotice = false,
  }) async {
    _authDio.clearAccessToken();
    _token = null;
    _currentUser = null;
    _refreshInFlight = null;
    onSessionCleared();
    if (!keepNotice) {
      _pendingNotice = null;
    }
    await _clearLegacySession?.call();
    if (notify) {
      notifyListeners();
    }
  }

  @protected
  void onCurrentUserLoaded(TUser user) {}

  @protected
  void onSessionCleared() {}
}

AuthFailure defaultLoginFailureMapper(Object error) {
  if (error is AuthFailure) {
    return error;
  }

  final statusCode = _statusCodeFor(error);
  if (statusCode == 400 || statusCode == 401) {
    return AuthFailure(AuthFailureReason.invalidCredentials, cause: error);
  }

  return AuthFailure(AuthFailureReason.unavailable, cause: error);
}

int? _statusCodeFor(Object error) {
  try {
    final response = (error as dynamic).response;
    final statusCode = response?.statusCode;
    return statusCode is int ? statusCode : null;
  } catch (_) {
    return null;
  }
}
