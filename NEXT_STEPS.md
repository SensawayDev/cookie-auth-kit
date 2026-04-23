# Next Steps

This file tracks the next improvements to consider when picking this repo back
up. The current baseline is a reusable auth kit with passing FastAPI and Dart
package tests.

## Priority 1: Runnable Examples

Build minimal runnable examples instead of README-only integration notes. The
examples should be aligned with the current package release version and pinned
tag (`0.2.0` / `v0.2.0`) in their setup docs.

Status: implemented in `examples/fastapi_app` and `examples/flutter_app` for
the current `0.2.0` package release.

FastAPI example:

- Add a small app under `examples/fastapi_app`.
- Use an in-memory user repository and refresh-token store.
- Expose `/auth/login`, `/auth/refresh`, `/auth/logout`, and `/users/me`.
- Demonstrate `CookieAuthConfig`, adapter protocols, CSRF config, and route
  helper usage.
- Include a short command sequence for installing and running the example.

Flutter example:

- Add a minimal Flutter web app under `examples/flutter_app`.
- Demonstrate `CookieAuthDio`, `DioCookieAuthApi`, `CookieAuthController`, login,
  restore, logout, and protected request retry.
- Keep roles, routing policy, and app profile fields in the example app, not the
  reusable package.

Validation:

```powershell
cd packages/fastapi_cookie_auth
..\..\.venv\Scripts\python.exe -m pytest

cd ..\cookie_auth_client
flutter test
flutter analyze
```

## Priority 2: Typed Failures And Error Codes

Add stable error identifiers for common auth failures without tying the package
to one app's UI.

Status: implemented with backend `X-Auth-Error-Code` headers plus Dart-side
`AuthFailureReason` mapping for the current `0.2.0` package baseline.

Backend candidates:

- Invalid credentials.
- Missing refresh token.
- Invalid refresh token.
- Revoked refresh token.
- Expired refresh token.
- Inactive user.
- Missing CSRF token.
- Invalid CSRF token.
- Untrusted origin.
- Cross-site request rejected.

Dart candidates:

- Preserve `AuthFailureReason.invalidCredentials`.
- Add distinguishable unavailable/session-expired/server-rejected cases if they
  are useful to apps.
- Keep app-specific message text outside the reusable package.

Compatibility requirement:

- Preserve HTTP status behavior unless the change is clearly documented and
  covered by tests.
- Avoid exposing sensitive detail to login responses.

## Priority 3: Adapter Protocol Documentation

Document exact backend adapter expectations in one place.

Status: implemented in `docs/adapters.md` for the current `0.2.0` package
baseline.

Add or expand docs for:

- `AuthUser`.
- `UserRepository`.
- `RefreshTokenRecord`.
- `RefreshTokenStore`.
- Expected transaction/commit behavior.
- Timezone-aware `expires_at` handling.
- Why refresh tokens are stored only as hashes.

Good target file:

```text
docs/adapters.md
```

## Priority 4: Release Notes

Add a changelog before publishing another tag.

Status: implemented in `CHANGELOG.md`, with an `Unreleased` section plus
baseline entries for `v0.2.0`, `v0.1.1`, and `v0.1.0`.

Suggested file:

```text
CHANGELOG.md
```

Initial entries should mention:

- `v0.2.0` baseline.
- Any dependency contract changes.
- Security-relevant behavior such as CSRF defaults, refresh rotation, and
  reserved JWT claim handling.

## Priority 5: Optional Session Helpers

Consider optional helpers for session/device listing only if they can stay
generic.

Keep out of scope:

- App user management.
- Roles and permissions.
- Device naming policy.
- Admin dashboards.

Potential generic pieces:

- Refresh-token metadata protocol.
- Session revocation helper.
- "Revoke all sessions for user" helper.

Do not implement this until the basic examples and adapter docs are complete.

## Known Environment Note

On this Windows workspace, pytest can leave `pytest-cache-files-*` directories
with denied permissions when cache writes fail. The pattern is ignored in
`.gitignore`. This appears environmental and does not currently affect test
results.
