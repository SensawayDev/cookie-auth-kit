# FastAPI Example App

This example is a runnable companion for `fastapi-cookie-auth` `0.2.0`.

It keeps the reusable auth mechanics in the package and keeps app-owned fields
such as `display_name` and `role` in the example app.

## What It Demonstrates

- `CookieAuthConfig` with local CORS, trusted origins, CSRF, and insecure local
  cookies
- in-memory `UserRepository`
- in-memory `RefreshTokenStore`
- `POST /auth/login`, `POST /auth/refresh`, `POST /auth/logout`
- protected `GET /users/me`
- `create_current_claims_dependency` for bearer-token routes

The example uses a one-minute access token TTL so the Flutter example can
demonstrate automatic refresh and retry behavior without any extra backend-only
demo routes.

## Demo Credentials

- Email: `demo@example.com`
- Password: `demo-password`

## Run From This Repo

From the repository root:

```powershell
cd examples/fastapi_app
..\..\.venv\Scripts\python.exe -m pip install -r requirements.txt
..\..\.venv\Scripts\python.exe -m app
```

The app listens on `http://localhost:8000`.

## Run With The Matching Git Tag

Outside this mono-repo, install the same package release the example targets:

```powershell
python -m pip install "fastapi-cookie-auth @ git+https://github.com/SensawayDev/cookie-auth-kit.git@v0.2.0#subdirectory=packages/fastapi_cookie_auth" "uvicorn[standard]"
```

Then copy the files from `examples/fastapi_app` and run:

```powershell
python -m app
```

## Local Configuration

Optional environment variables:

```env
COOKIE_AUTH_EXAMPLE_ALLOWED_ORIGINS=http://localhost:8080,http://127.0.0.1:8080,http://localhost:8000,http://127.0.0.1:8000
COOKIE_AUTH_EXAMPLE_TRUSTED_ORIGINS=http://localhost:8080,http://127.0.0.1:8080,http://localhost:8000,http://127.0.0.1:8000
COOKIE_AUTH_EXAMPLE_JWT_SECRET=dev-secret-v0.2.0
COOKIE_AUTH_EXAMPLE_ACCESS_TOKEN_MINUTES=1
COOKIE_AUTH_EXAMPLE_REFRESH_TOKEN_DAYS=7
COOKIE_AUTH_EXAMPLE_REFRESH_COOKIE_SECURE=false
```

Use `http://localhost:8080` for the Flutter web example so the default trusted
origin and CORS settings line up with the backend.
