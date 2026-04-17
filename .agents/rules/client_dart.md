# Dart Client Package Rules

Scope: `packages/cookie_auth_client`.

This package provides reusable Flutter/Dart auth mechanics for first-party web
apps using in-memory access tokens and backend-managed `HttpOnly` refresh
cookies. It must not become an app-specific auth provider.

## Design Boundary

- Keep routing, dashboards, roles, permissions, tenants, and profile fields out
  of the package.
- Apps should extend or wrap `CookieAuthController<TUser>` for app-specific
  state such as roles or route decisions.
- Apps should adapt their own generated/API clients to `CookieAuthApi` when
  direct `DioCookieAuthApi` use is not appropriate.
- Keep access tokens in memory only. Do not add localStorage/sessionStorage token
  persistence.
- The refresh token is intentionally unreadable by JavaScript because it lives in
  a backend-managed `HttpOnly` cookie.

## Current Public Concepts

- `AccessToken` is the in-memory bearer token value.
- `CookieAuthApi` abstracts login, refresh, and logout.
- `DioCookieAuthApi` calls configurable auth endpoints and uses credentialed
  requests for cookie-backed routes.
- `CookieAuthDio` owns bearer injection, CSRF header attachment, refresh on
  non-auth `401`, and one retry per failed request.
- `CookieAuthController<TUser>` owns generic auth state, session restore, login,
  logout, single-flight refresh, session expiry notice, and lifecycle hooks.
- `cookieAuthWithCredentials` marks Dio requests that should include CSRF header
  behavior through `extra['withCredentials'] == true`.

## Backend Contract

Default endpoints are:

- `POST /auth/login`
- `POST /auth/refresh`
- `POST /auth/logout`

Default token JSON parser expects:

```json
{
  "access_token": "jwt",
  "token_type": "bearer"
}
```

Credentialed auth routes should mirror the readable CSRF cookie into the
configured header. Defaults are:

- CSRF cookie: `cookie_auth_csrf`
- CSRF header: `x-csrf-token`

If apps customize names, pass the same names to both `CookieAuthDio` and
`DioCookieAuthApi`.

## Behavior Rules

- `CookieAuthController.restoreSession()` should fail quietly and leave the user
  logged out when refresh fails.
- `CookieAuthController.logout()` should clear local state even when backend
  logout fails.
- `refreshAccessToken()` should keep a single in-flight refresh request and
  share it across callers.
- `CookieAuthDio` should not attempt refresh for auth endpoint failures.
- `CookieAuthDio` should retry a protected request at most once after a
  successful refresh.
- `expireSession()` should clear local state and expose
  `AuthNotice.sessionExpired`.
- Avoid adding persistence or UI concerns to the package; expose hooks or
  generic state instead.

## Testing Expectations

Add or update tests in `packages/cookie_auth_client/test` for changes to:

- login, restore, logout, local cleanup, or notice behavior
- refresh single-flight behavior
- Dio bearer token set/clear behavior
- retry-after-401 behavior
- auth-path exclusions from retry
- CSRF cookie/header attachment for credentialed requests
- token response parsing and configurable endpoint/field names

Preferred local commands:

```powershell
cd packages/cookie_auth_client
flutter pub get
flutter test
flutter analyze
```

## Compatibility Notes

- Dart SDK constraint is currently `^3.10.3`; Flutter lower bound is
  `>=1.17.0`.
- Lints come from `package:flutter_lints/flutter.yaml`.
- Keep `lib/cookie_auth_client.dart` exports in sync when adding public APIs.
- Preserve compatibility with the FastAPI package default response shape and
  auth endpoint semantics.
