# Changelog

All notable changes to this repository should be recorded in this file.

The repository ships two packages that should stay aligned when practical:

- `fastapi-cookie-auth`
- `cookie_auth_client`

## [Unreleased]

- No unreleased changes yet.

## [v0.2.0] - 2026-04-23

### Added

- Runnable FastAPI and Flutter example apps under `examples/fastapi_app` and
  `examples/flutter_app`, aligned to the current `0.2.0` package baseline.
- Stable backend auth error codes via the `X-Auth-Error-Code` response header.
- Dart-side `AuthFailureReason.sessionExpired` and
  `AuthFailureReason.serverRejected` mappings in addition to the existing
  `invalidCredentials` and `unavailable` cases.
- Backend adapter protocol documentation in `docs/adapters.md`.

### Changed

- Repository docs now treat the runnable examples, typed auth failure mapping,
  and adapter protocol guide as first-class documented parts of the kit.
- Flutter example UI now handles the expanded auth failure reasons.

### Security

- Auth rejection paths now expose stable machine-readable codes without changing
  the existing `401`/`403` HTTP behavior.
- Docs now explicitly call out the need to expose `X-Auth-Error-Code` in CORS
  when browser clients must read it cross-origin.

## [v0.1.1] - 2026-04-16

### Added

- Monorepo package baseline for:
  - `fastapi-cookie-auth` `0.1.1`
  - `cookie_auth_client` `0.1.1`
- `NEXT_STEPS.md` to track follow-up work after the initial reusable kit
  extraction.

### Changed

- Package version alignment from the initial `0.1.0` baseline to `0.1.1`.
- Dependency installation guidance standardized around pinned git tags and
  subdirectory references:
  - Python:
    `fastapi-cookie-auth @ git+https://github.com/SensawayDev/cookie-auth-kit.git@v0.1.1#subdirectory=packages/fastapi_cookie_auth`
  - Dart:
    `ref: v0.1.1` with `path: packages/cookie_auth_client`

### Security

- Preserved the core browser-auth contract:
  - short-lived bearer access tokens kept in Flutter memory
  - opaque refresh tokens stored in backend-managed `HttpOnly` cookies
  - server-side refresh-token hashing
  - refresh-token rotation on `/auth/refresh`
  - CSRF cookie/header validation for refresh and logout
  - reserved JWT access-token claims (`sub`, `typ`, `iat`, `exp`) protected from
    override by `extra_claims`

## [v0.1.0] - 2026-04-16

### Added

- Initial standalone `cookie-auth-kit` repository extracted from Blue Farm.
- `fastapi-cookie-auth` package for:
  - Argon2 password hashing and verification
  - access-token creation and validation
  - refresh-token generation, hashing, rotation, and revocation
  - cookie helpers for refresh and CSRF tokens
  - CSRF/origin validation helpers
  - login/refresh/logout route helpers
- `cookie_auth_client` package for:
  - in-memory access token handling
  - `DioCookieAuthApi`
  - `CookieAuthDio`
  - `CookieAuthController<TUser>`
  - one-time refresh and retry behavior for protected requests
- Core repo docs for deployment, security, and package usage.

### Security

- Established the intended first-party browser auth model:
  - `HttpOnly` refresh cookies
  - short-lived in-memory access tokens
  - readable CSRF cookie mirrored into a request header
  - explicit trusted-origin guidance for credentialed browser requests
