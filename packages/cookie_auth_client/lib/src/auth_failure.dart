const cookieAuthErrorCodeHeader = 'x-auth-error-code';

enum AuthFailureReason {
  invalidCredentials,
  sessionExpired,
  serverRejected,
  unavailable,
}

class AuthFailure implements Exception {
  const AuthFailure(
    this.reason, {
    this.cause,
    this.statusCode,
    this.backendCode,
  });

  final AuthFailureReason reason;
  final Object? cause;
  final int? statusCode;
  final String? backendCode;
}

AuthFailure authFailureFromError(Object error) {
  if (error is AuthFailure) {
    return error;
  }

  final statusCode = _statusCodeFor(error);
  final backendCode = _backendCodeFor(error);
  final reason = _reasonFor(statusCode: statusCode, backendCode: backendCode);
  return AuthFailure(
    reason,
    cause: error,
    statusCode: statusCode,
    backendCode: backendCode,
  );
}

AuthFailureReason _reasonFor({
  required int? statusCode,
  required String? backendCode,
}) {
  switch (backendCode) {
    case 'invalid_credentials':
      return AuthFailureReason.invalidCredentials;
    case 'missing_refresh_token':
    case 'invalid_refresh_token':
    case 'revoked_refresh_token':
    case 'expired_refresh_token':
    case 'inactive_user':
    case 'invalid_access_token':
    case 'invalid_token_type':
    case 'invalid_token_payload':
      return AuthFailureReason.sessionExpired;
    case 'missing_csrf_token':
    case 'invalid_csrf_token':
    case 'untrusted_origin':
    case 'cross_site_request_rejected':
      return AuthFailureReason.serverRejected;
  }

  if (statusCode == 400 || statusCode == 401) {
    return AuthFailureReason.invalidCredentials;
  }
  if (statusCode == 403) {
    return AuthFailureReason.serverRejected;
  }
  return AuthFailureReason.unavailable;
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

String? _backendCodeFor(Object error) {
  try {
    final response = (error as dynamic).response;
    final headers = response?.headers;
    final value = headers?.value(cookieAuthErrorCodeHeader);
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
  } catch (_) {
    return null;
  }
  return null;
}
