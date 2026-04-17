# Cookie Auth Kit Codex Handoff

This file is context for continuing independent development of the reusable
cookie auth kit in another repository.

## Repository

Target standalone repository:

```text
git@github.com:SensawayDev/cookie-auth-kit.git
```

Blue Farm currently consumes the kit by tag:

```text
v0.1.0
```

Backend dependency in `backend/api/requirements.txt`:

```text
fastapi-cookie-auth @ git+https://github.com/SensawayDev/cookie-auth-kit.git@v0.1.0#subdirectory=packages/fastapi_cookie_auth
```

Flutter dependency in `frontend/apps/farm_manager_main_app/pubspec.yaml`:

```yaml
cookie_auth_client:
  git:
    url: https://github.com/SensawayDev/cookie-auth-kit.git
    path: packages/cookie_auth_client
    ref: v0.1.0
```

HTTPS is used for consuming dependencies so Docker builds and CI do not need
SSH agent forwarding.

## Intended Package Shape

The standalone repository should keep this structure:

```text
cookie-auth-kit/
  .github/workflows/test.yml
  README.md
  docs/
    deployment.md
    security.md
  examples/
    fastapi_app/README.md
    flutter_app/README.md
  packages/
    cookie_auth_client/
    fastapi_cookie_auth/
```

The kit intentionally does not own app users. Each consuming app owns:

- user model and persistence
- refresh-token database table/model
- roles and permissions
- registration, invitation, password reset, and `/users/me`
- app-specific Flutter auth provider and route guards

The kit owns only reusable auth mechanics:

- short-lived access tokens kept in Flutter memory
- opaque refresh token in an `HttpOnly` cookie
- server-side refresh-token hashing, rotation, revocation helpers
- CSRF cookie/header support for cookie-backed routes
- Fetch Metadata and Origin validation helpers
- Flutter login, logout, refresh, restore, and retry behavior

## Current Security Contract

Production apps should run with:

```env
REFRESH_COOKIE_SECURE=true
REFRESH_COOKIE_SAMESITE=lax
CSRF_PROTECTION_ENABLED=true
CORS_ALLOW_ORIGINS=https://app.example.com
CSRF_TRUSTED_ORIGINS=https://app.example.com
```

For same-origin deployments, prefer:

```text
https://app.example.com/       Flutter web app
https://app.example.com/api    FastAPI backend behind a reverse proxy
```

Local HTTP development can use:

```env
REFRESH_COOKIE_SECURE=false
CORS_ALLOW_ORIGINS=http://localhost,http://localhost:8087
CSRF_TRUSTED_ORIGINS=http://localhost,http://localhost:8087
```

The readable CSRF cookie is not a secret. It is mirrored into the configured
CSRF request header by the Flutter client for refresh/logout and other
credentialed cookie-backed requests.

## Blue Farm Integration Expectations

Blue Farm imports the FastAPI package from:

- `backend/api/app/modules/auth/config.py`
- `backend/api/app/modules/auth/dependencies.py`
- `backend/api/app/modules/auth/router.py`
- `backend/api/app/modules/auth/service.py`
- `backend/api/app/modules/users/service.py`
- `backend/api/app/cli/create_superadmin.py`

Blue Farm imports the Flutter package from:

- `frontend/apps/farm_manager_main_app/lib/providers/auth_provider.dart`

Blue Farm also has CSRF header support in its API package:

- `frontend/packages/blue_farm_api/lib/src/api_client.dart`
- `frontend/packages/blue_farm_api/lib/src/csrf_cookie_reader*.dart`

When changing package behavior, check whether Blue Farm also needs updates to:

- backend auth adapters, route wrappers, settings, or tests
- `frontend/packages/blue_farm_api`
- app auth provider behavior
- `backend/README.md`
- `backend/API_ENDPOINTS.md`
- `example.env`
- `docker-compose.yml`
- `scripts/build_deploy.py`

## Validation Commands

In the standalone kit repository:

```bash
cd packages/fastapi_cookie_auth
python -m pip install -e ".[test]"
python -m pytest
```

```bash
cd packages/cookie_auth_client
flutter pub get
flutter test
flutter analyze
```

In Blue Farm after publishing a new kit tag:

```bash
cd backend/api
python -m pip install -r requirements.txt
python -m pytest tests/test_settings.py tests/test_auth_cookie_flow.py tests/test_users_service.py
```

```bash
cd frontend/apps/farm_manager_main_app
flutter pub get
flutter test test/auth_provider_test.dart test/login_page_test.dart test/widget_test.dart
flutter analyze
```

```bash
docker compose config
docker compose build api
```

## Release Flow

Use matching package versions for both packages when possible.

1. Update the package code and docs in the standalone repository.
2. Run both package test suites.
3. Commit and tag, for example `v0.1.1`.
4. Push the tag.
5. Update Blue Farm dependency refs from `v0.1.0` to the new tag.
6. Run the Blue Farm validation commands above.

Consuming apps should pin tags, not moving branches.

## Good Next Improvements

- Add a minimal runnable FastAPI example app with an in-memory user repository
  and refresh-token store.
- Add a minimal runnable Flutter web example that demonstrates session restore,
  logout, and automatic refresh retry behavior.
- Add typed exceptions or error codes for common auth failures.
- Document exact adapter protocols for `UserRepository` and
  `RefreshTokenStore`.
- Consider optional session/device listing helpers, while still keeping user and
  role ownership inside each consuming app.
- Add release notes or a changelog once versions start moving beyond `0.1.x`.
