# cookie_auth_client

Reusable Flutter/Dart auth helpers for first-party web apps that keep access
tokens in memory and keep refresh tokens in backend-managed `HttpOnly` cookies.

This package is intentionally small. It is not an OAuth/OIDC client, and it does
not know about an app's user roles, routing destinations, dashboards, or UI. It
only owns the generic auth mechanics that tend to repeat across apps.

## What It Does

- keeps the access token in memory only
- expects the backend to store the refresh token in an `HttpOnly` cookie
- restores a browser session by calling `/auth/refresh`
- logs in and logs out through configurable auth endpoints
- injects `Authorization: Bearer <access-token>` into a Dio client
- refreshes and retries a failed request once after a `401`
- keeps only one refresh request in flight
- attaches a CSRF header from a readable cookie for credentialed requests
- exposes generic auth state through `CookieAuthController<TUser>`

## Backend Contract

The default `DioCookieAuthApi` expects this backend behavior.

`POST /auth/login`

- accepts username/password form fields
- returns access-token JSON
- sets the refresh token as an `HttpOnly` cookie
- sets a readable CSRF cookie

`POST /auth/refresh`

- reads the refresh token from the cookie
- validates the CSRF header against the readable CSRF cookie
- rotates the refresh token
- sets replacement refresh and CSRF cookies
- returns access-token JSON

`POST /auth/logout`

- reads the refresh token from the cookie
- validates the CSRF header when the refresh cookie is present
- revokes it if present
- clears the refresh and CSRF cookies

Normal API requests should use the in-memory access token:

```http
Authorization: Bearer <access-token>
```

The default token JSON parser expects:

```json
{
  "access_token": "jwt",
  "token_type": "bearer"
}
```

## Security Notes

- The refresh token should be in an `HttpOnly` cookie so JavaScript cannot read
  it.
- Production cookies should use `Secure`.
- Use `SameSite=Lax` or stricter unless your deployment needs cross-site auth.
- Keep CORS origins explicit when credentials are enabled. Do not combine
  wildcard origins with credentialed requests.
- Use Fetch Metadata and Origin checks on the backend for cookie-backed routes.
- Use a double-submit CSRF cookie/header for refresh and logout.
- Access tokens are still available to JavaScript while the page is open, so
  use normal XSS defenses such as output encoding and a Content Security Policy.

## Installation

As a local path dependency:

```yaml
dependencies:
  cookie_auth_client:
    path: ../../packages/cookie_auth_client
```

As a future standalone Git dependency:

```yaml
dependencies:
  cookie_auth_client:
    git:
      url: https://github.com/SensawayDev/cookie-auth-kit.git
      path: packages/cookie_auth_client
      ref: v0.1.1
```

## Basic Usage

```dart
final dio = Dio(BaseOptions(baseUrl: '/api'));
final authDio = CookieAuthDio(dio);
final authApi = DioCookieAuthApi(dio);

final auth = CookieAuthController<MyUser>(
  authApi: authApi,
  authDio: authDio,
  loadCurrentUser: () => myUserService.getMe(),
);

await auth.restoreSession();
```

Login:

```dart
await auth.login(email, password);
```

Logout:

```dart
await auth.logout();
```

Use `authDio.dio` or the same `dio` instance for authenticated API services.
`CookieAuthDio` will attach the bearer token and retry once after a refreshable
`401`.

For app-specific CSRF cookie names, pass the same name to both helpers:

```dart
final authDio = CookieAuthDio(
  dio,
  csrfCookieName: 'my_app_csrf_token',
);
final authApi = DioCookieAuthApi(
  dio,
  csrfCookieName: 'my_app_csrf_token',
);
```

## Router Example

With `go_router`, keep app-specific destinations in the app:

```dart
redirect: (context, state) {
  if (auth.isRestoringSession) {
    return '/boot';
  }
  if (!auth.isAuthenticated) {
    return '/login';
  }
  return null;
}
```

## App-Specific Adapter

If your app already has an API package, adapt it to `CookieAuthApi` instead of
using `DioCookieAuthApi` directly:

```dart
class MyAppCookieAuthApi implements CookieAuthApi {
  MyAppCookieAuthApi(this.authService);

  final AuthService authService;

  @override
  Future<AccessToken> login({
    required String username,
    required String password,
  }) async {
    final token = await authService.login(username, password);
    return AccessToken(value: token.accessToken, tokenType: token.tokenType);
  }

  @override
  Future<AccessToken> refresh() async {
    final token = await authService.refreshToken();
    return AccessToken(value: token.accessToken, tokenType: token.tokenType);
  }

  @override
  Future<void> logout() => authService.logout();
}
```

Then add app-specific convenience state in your app, not in this package:

```dart
class MyAuthProvider extends CookieAuthController<MyUser> {
  MyAuthProvider({
    required CookieAuthApi authApi,
    required CookieAuthDio authDio,
    required UserService userService,
  }) : super(
         authApi: authApi,
         authDio: authDio,
         loadCurrentUser: userService.getMe,
       );

  bool get isAdmin => currentUser?.role == 'admin';
}
```

## Testing

In tests, fake `CookieAuthApi` and `loadCurrentUser`:

```dart
final auth = CookieAuthController<MyUser>(
  authApi: FakeCookieAuthApi(),
  authDio: CookieAuthDio(Dio()),
  loadCurrentUser: () async => const MyUser(id: 'user-1'),
);
```

The package tests include examples for:

- login success and failure
- quiet restore failure
- logout local cleanup
- single-flight refresh
- Dio refresh-and-retry behavior

## Using From This Repository

Install from this mono-repo with a Git dependency:

```yaml
dependencies:
  cookie_auth_client:
    git:
      url: https://github.com/SensawayDev/cookie-auth-kit.git
      path: packages/cookie_auth_client
      ref: v0.1.1
```

Run local checks:

```bash
flutter pub get
flutter test
flutter analyze
```

Keep the package focused on:

```text
Dio + in-memory access token + HttpOnly refresh cookie + generic auth state
```

Everything app-specific belongs in each consuming app.
