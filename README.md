# cookie-auth-kit

Reusable auth kit for first-party Flutter web apps backed by FastAPI.

The kit contains two small packages:

```text
packages/
  cookie_auth_client/      # Flutter/Dart client package
  fastapi_cookie_auth/     # Python/FastAPI helper package
```

It implements an app-owned user model pattern:

- the packages own generic auth mechanics
- each app owns users, roles, permissions, registration rules, and `/users/me`

## What It Provides

- in-memory bearer access tokens
- backend-managed `HttpOnly` refresh cookies
- refresh-token hashing, rotation, and revocation helpers
- CSRF cookie/header support for cookie-backed routes
- Fetch Metadata and Origin validation helpers
- Flutter session restore, login, logout, refresh, and retry behavior

## What Apps Still Own

Backend apps own:

- `User` model
- `RefreshToken` table/model
- migrations
- `UserRepository` adapter
- `RefreshTokenStore` adapter
- registration and password reset flows
- roles and permissions
- `/users/me`

Flutter apps own:

- route guards
- app-specific `AuthProvider`
- role/dashboard state
- user profile model and service

## Install In A Flutter App

```yaml
dependencies:
  cookie_auth_client:
    git:
      url: https://github.com/SensawayDev/cookie-auth-kit.git
      path: packages/cookie_auth_client
      ref: v0.1.1
```

## Install In A FastAPI App

```text
fastapi-cookie-auth @ git+https://github.com/SensawayDev/cookie-auth-kit.git@v0.1.1#subdirectory=packages/fastapi_cookie_auth
```

## Local Checks

Python package:

```bash
cd packages/fastapi_cookie_auth
python -m pip install -e ".[test]"
python -m pytest
```

Flutter package:

```bash
cd packages/cookie_auth_client
flutter pub get
flutter test
flutter analyze
```

## Release

Start with matching package versions:

```text
fastapi-cookie-auth 0.1.1
cookie_auth_client 0.1.1
```

Tag the repository:

```bash
git tag v0.1.1
git push origin v0.1.1
```

Consuming apps should depend on tags, not moving branches.

## Docs

- [Security](docs/security.md)
- [Deployment](docs/deployment.md)
- [FastAPI example app](examples/fastapi_app/README.md)
- [Flutter web example app](examples/flutter_app/README.md)
