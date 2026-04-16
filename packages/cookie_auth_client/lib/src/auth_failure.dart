enum AuthFailureReason { invalidCredentials, unavailable }

class AuthFailure implements Exception {
  const AuthFailure(this.reason, {this.cause});

  final AuthFailureReason reason;
  final Object? cause;
}
