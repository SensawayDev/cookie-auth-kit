# Deployment

## Same-Origin Recommended Setup

The simplest production shape is:

```text
https://app.example.com/       Flutter web app
https://app.example.com/api    FastAPI backend through reverse proxy
```

Example env:

```env
API_ROOT_PATH=/api

JWT_SECRET=<long-random-secret>
ACCESS_TOKEN_MINUTES=15
REFRESH_TOKEN_DAYS=30

REFRESH_COOKIE_NAME=app_refresh_token
REFRESH_COOKIE_PATH=/api/auth
REFRESH_COOKIE_SECURE=true
REFRESH_COOKIE_SAMESITE=lax

CSRF_PROTECTION_ENABLED=true
CSRF_COOKIE_NAME=app_csrf_token
CSRF_COOKIE_PATH=/
CSRF_HEADER_NAME=x-csrf-token

CORS_ALLOW_ORIGINS=https://app.example.com
CSRF_TRUSTED_ORIGINS=https://app.example.com
```

## Local Development

For local HTTP testing:

```env
REFRESH_COOKIE_SECURE=false
CORS_ALLOW_ORIGINS=http://localhost,http://localhost:8087
CSRF_TRUSTED_ORIGINS=http://localhost,http://localhost:8087
```

Browsers compare origins exactly. `http://localhost` and
`http://localhost:8087` are different origins.

## Cross-Site Deployments

Cross-site deployments need more care. If the app is at
`https://app.example.com` and the API is at `https://api.example.com`, make sure:

- CORS allows the app origin
- credentialed requests are enabled
- cookies have an appropriate domain/path
- the frontend can read the CSRF cookie
- `SameSite=None` requires `Secure=true`

Same-origin deployment is preferred unless you have a concrete reason to split
frontend and API origins.
