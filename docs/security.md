# Security

This kit is designed for first-party apps where the frontend and backend are
controlled by the same team.

## Token Model

- access token: short-lived bearer token kept in memory by the frontend
- refresh token: opaque random token stored in an `HttpOnly` cookie
- refresh token at rest: stored server-side as a hash
- CSRF token: readable cookie mirrored into a request header for cookie-backed
  auth routes

## Required Production Settings

Use HTTPS and secure cookies:

```env
REFRESH_COOKIE_SECURE=true
REFRESH_COOKIE_SAMESITE=lax
CSRF_PROTECTION_ENABLED=true
```

Set trusted origins explicitly:

```env
CORS_ALLOW_ORIGINS=https://app.example.com
CSRF_TRUSTED_ORIGINS=https://app.example.com
```

Use a strong JWT secret:

```bash
openssl rand -hex 32
```

## CSRF

The FastAPI package provides:

- `Sec-Fetch-Site` rejection for cross-site browser requests
- optional Origin allow-list validation
- double-submit CSRF cookie/header validation for refresh/logout

The readable CSRF cookie is not a secret. It proves the calling JavaScript is
running in an origin that can read first-party cookies for the app.

## XSS

Access tokens are available to JavaScript while the page is open. Use normal XSS
defenses:

- output encoding
- framework-safe rendering
- dependency hygiene
- Content Security Policy where practical

## Out Of Scope

The kit does not currently provide:

- OIDC/OAuth provider integration
- MFA
- password reset
- email verification
- device/session management UI
- asymmetric JWT signing/JWKS
