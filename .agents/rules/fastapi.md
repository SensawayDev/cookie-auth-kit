# FastAPI Package Rules

Scope: `packages/fastapi_cookie_auth`.

This package provides reusable FastAPI helpers for bearer access tokens and
backend-managed `HttpOnly` refresh cookies. It must remain app-agnostic.

## Design Boundary

- Keep user persistence out of the package. Apps provide concrete user models,
  database sessions, refresh-token tables, and Alembic migrations.
- Keep roles, permissions, tenant rules, profile fields, registration, password
  reset, invitations, and `/users/me` out of this package.
- Prefer protocols and callback hooks over app-specific types. Current adapter
  protocols live in `fastapi_cookie_auth/types.py`.
- Route helpers should orchestrate reusable mechanics only; consuming apps own
  actual FastAPI routers, dependencies, config loading, and database lifecycle.

## Current Public Concepts

- `CookieAuthConfig` in `config.py` carries JWT, refresh-cookie, CSRF, and
  trusted-origin settings.
- `AuthUser`, `UserRepository`, `RefreshTokenRecord`, and `RefreshTokenStore`
  are structural protocols.
- `login_with_password`, `refresh_from_cookie`, and `logout_from_cookie`
  implement the default auth route behavior.
- `issue_login_tokens`, `rotate_refresh_token`, and `revoke_refresh_token`
  manage refresh-token lifecycle.
- `set_refresh_cookie`/`clear_refresh_cookie` also set/clear the readable CSRF
  cookie when CSRF protection is enabled.
- `validate_csrf_request` rejects cross-site Fetch Metadata, validates trusted
  origins when configured, and performs double-submit CSRF checks when required.

## Security Rules

- Refresh tokens must remain opaque random strings in cookies and must be stored
  server-side only as hashes.
- Rotate refresh tokens on every refresh and revoke the previous token before
  committing the replacement.
- Keep access tokens short-lived and mark them with `typ: "access"`.
- Use timezone-aware datetimes, preferably `datetime.now(timezone.utc)`.
- Do not weaken CSRF defaults. If adding options, keep secure production defaults
  and document local-development exceptions.
- Do not use wildcard CORS/origin guidance for credentialed browser requests.
- Treat the readable CSRF cookie as non-secret; its purpose is double-submit
  validation from a trusted first-party origin.

## Error Behavior

- Current helpers raise FastAPI `HTTPException` with `401` for invalid/missing
  credentials, invalid tokens, revoked refresh tokens, expired refresh tokens,
  and inactive users.
- CSRF and origin failures use `403`.
- If adding typed exceptions or error codes, preserve HTTP behavior unless a
  migration note and tests cover the change.

## Testing Expectations

Add or update tests in `packages/fastapi_cookie_auth/tests/test_cookie_auth.py`
for changes to:

- token payload shape or JWT validation
- password hashing/verification
- refresh-token hashing, rotation, revocation, expiry, or commit behavior
- cookie attributes, paths, security flags, or CSRF cookie behavior
- route helper login/refresh/logout behavior
- CSRF Fetch Metadata, Origin, or double-submit validation

Preferred local commands:

```powershell
cd packages/fastapi_cookie_auth
python -m pip install -e ".[test]"
python -m pytest
```

## Compatibility Notes

- Python package metadata currently requires Python `>=3.12`.
- Keep exported public symbols in `fastapi_cookie_auth/__init__.py` in sync when
  adding public APIs.
- Preserve the default JSON response contract expected by the Dart package:
  `access_token` plus `token_type`.
- Preserve default auth endpoint semantics used by clients:
  `/auth/login`, `/auth/refresh`, and `/auth/logout`.
