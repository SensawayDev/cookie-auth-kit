# Cookie Auth Kit Context

This repository is a standalone reusable auth/token workflow kit for first-party
Flutter web apps backed by FastAPI. It was extracted from Blue Farm and is
consumed by apps through pinned git tags.

## Repository Shape

```text
packages/
  fastapi_cookie_auth/     # Python/FastAPI helper package
  cookie_auth_client/      # Flutter/Dart client package
docs/
  adapters.md
  deployment.md
  security.md
CHANGELOG.md
examples/
  fastapi_app/           # runnable FastAPI example app
  flutter_app/           # runnable Flutter web example app
```

The intended package names are:

- Python: `fastapi-cookie-auth`
- Dart: `cookie_auth_client`

Keep package versions aligned when practical. Current baseline is `0.1.1`.
Consuming apps should pin tags, not moving branches.

## Ownership Boundary

The kit owns reusable auth mechanics only:

- short-lived bearer access tokens kept in Flutter memory
- opaque refresh token stored in a backend-managed `HttpOnly` cookie
- server-side refresh-token hashing, rotation, and revocation helpers
- CSRF readable cookie/header support for cookie-backed routes
- stable backend auth error codes for common failure cases
- Fetch Metadata and Origin validation helpers
- Flutter login, logout, refresh, restore, and one-time retry behavior

Consuming apps own all application-specific identity and authorization:

- user model and persistence
- refresh-token database table/model and migrations
- roles, permissions, tenant rules, and app profile data
- registration, invitation, password reset, email verification, and `/users/me`
- app-specific Flutter auth provider, route guards, dashboards, and user state

Do not add app-owned concepts such as roles, superadmin behavior, route names, or
profile fields to the reusable packages. Prefer extension points, protocol
adapters, callbacks, and examples.

## Security Contract

Production apps should use HTTPS, secure refresh cookies, explicit origins, and
CSRF protection:

```env
REFRESH_COOKIE_SECURE=true
REFRESH_COOKIE_SAMESITE=lax
CSRF_PROTECTION_ENABLED=true
CORS_ALLOW_ORIGINS=https://app.example.com
CSRF_TRUSTED_ORIGINS=https://app.example.com
```

Recommended deployment shape:

```text
https://app.example.com/       Flutter web app
https://app.example.com/api    FastAPI backend behind a reverse proxy
```

Local HTTP development may use insecure cookies and explicit localhost origins:

```env
REFRESH_COOKIE_SECURE=false
CORS_ALLOW_ORIGINS=http://localhost,http://localhost:8087
CSRF_TRUSTED_ORIGINS=http://localhost,http://localhost:8087
```

The readable CSRF cookie is not a secret. The frontend mirrors it into the
configured CSRF request header for credentialed refresh/logout and other
cookie-backed requests.

## Backend HTTP Contract

The default helper behavior supports:

- `POST /auth/login`: validates credentials, returns access-token JSON, sets the
  `HttpOnly` refresh cookie, and sets a readable CSRF cookie.
- `POST /auth/refresh`: reads the refresh cookie, validates CSRF, rotates the
  refresh token, returns access-token JSON, and sets replacement cookies.
- `POST /auth/logout`: reads the refresh cookie, validates CSRF when a refresh
  cookie is present, revokes it if present, and clears refresh/CSRF cookies.

Normal app endpoints should use:

```http
Authorization: Bearer <access-token>
```

Default token JSON shape:

```json
{
  "access_token": "jwt",
  "token_type": "bearer"
}
```

## Public API Anchors

FastAPI package:

- `CookieAuthConfig`
- `AuthUser`, `UserRepository`, `RefreshTokenStore` protocols
- `hash_password`, `verify_password`
- `create_access_token`, `decode_access_token`
- `new_refresh_token`, `hash_refresh_token`, `issue_login_tokens`,
  `rotate_refresh_token`, `revoke_refresh_token`
- `set_refresh_cookie`, `clear_refresh_cookie`
- `validate_csrf_request`
- `AuthErrorCode`, `AUTH_ERROR_CODE_HEADER`
- route helpers in `fastapi_cookie_auth.router`

Dart package:

- `AccessToken`
- `CookieAuthApi` and `DioCookieAuthApi`
- `CookieAuthDio`
- `CookieAuthController<TUser>`
- `AuthFailure`, `AuthNotice`
- `authFailureFromError`
- `cookieAuthWithCredentials`
- CSRF cookie reader abstractions

## Validation Commands

Python package:

```powershell
cd packages/fastapi_cookie_auth
python -m pip install -e ".[test]"
python -m pytest
```

Dart package:

```powershell
cd packages/cookie_auth_client
flutter pub get
flutter test
flutter analyze
```

When changing shared behavior, update package README/docs and tests in the same
change. If a future release is intended, tag the repository and update consuming
apps to the new tag.

## Blue Farm Integration Notes

Blue Farm should consume the kit by a pinned release tag. The current release
baseline is `v0.1.1`.

Backend dependency shape:

```text
fastapi-cookie-auth @ git+https://github.com/SensawayDev/cookie-auth-kit.git@v0.1.1#subdirectory=packages/fastapi_cookie_auth
```

Flutter dependency shape:

```yaml
cookie_auth_client:
  git:
    url: https://github.com/SensawayDev/cookie-auth-kit.git
    path: packages/cookie_auth_client
    ref: v0.1.1
```

Use HTTPS git URLs for dependencies so Docker builds and CI do not require SSH
agent forwarding.

When package behavior changes, check whether Blue Farm also needs updates to its
backend auth adapters, route wrappers, settings/tests, API CSRF client support,
frontend auth provider, env/docs, Docker config, or deployment scripts.

## Near-Term Improvements

- Keep the runnable FastAPI example app aligned with the current package
  release and backend adapter contract.
- Keep the runnable Flutter web example aligned with the current package
  release and browser auth flow behavior.
- Keep typed auth error codes and Dart failure mappings aligned with the current
  backend contract.
- Keep `docs/adapters.md` aligned with the current adapter protocol and commit
  behavior.
- Consider optional session/device listing helpers without moving ownership of
  users, roles, or app policy into the kit.
- Keep `CHANGELOG.md` updated before publishing the next tag.
