# Flutter Web Example App

This example is a runnable companion for `cookie_auth_client` `0.1.1`.

It uses the package for generic session mechanics and keeps app-owned fields
such as `display_name` and `role` in the example app.

## What It Demonstrates

- one shared `Dio` client
- `CookieAuthDio`
- `DioCookieAuthApi`
- `CookieAuthController`
- restore on boot
- login and logout
- a protected `/users/me` request that will refresh and retry once after a `401`

The paired FastAPI example uses a one-minute access token TTL. After login, wait
about 65 seconds and then reload `/users/me` to see the automatic refresh flow.

## Run The Backend First

```powershell
cd examples/fastapi_app
..\..\.venv\Scripts\python.exe -m app
```

The backend default origin/trusted-origin settings expect the Flutter app at
`http://localhost:8080`.

## Run The Flutter Example

```powershell
cd examples/flutter_app
flutter pub get
flutter run -d chrome --web-hostname localhost --web-port 8080 --dart-define=API_BASE_URL=http://localhost:8000
```

## Dependency Shape

Inside this repo the example uses a path dependency so it stays aligned with the
local `cookie_auth_client` package version `0.1.1`.

For external apps, the matching git dependency is:

```yaml
dependencies:
  cookie_auth_client:
    git:
      url: https://github.com/SensawayDev/cookie-auth-kit.git
      path: packages/cookie_auth_client
      ref: v0.1.1
```

## Demo Credentials

- Email: `demo@example.com`
- Password: `demo-password`
