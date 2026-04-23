# fastapi_cookie_auth

Reusable FastAPI helpers for first-party apps that use bearer access tokens and
backend-managed `HttpOnly` refresh cookies.

This package is a module to install inside each app backend. It does not own
users, roles, tenants, or app profile data. Each app keeps its own user model
and database. The package owns only the generic auth mechanics.

## What The Package Provides

- Argon2 password hashing and verification
- access-token creation and validation
- refresh-token generation and hashing
- refresh-token rotation and revocation workflows
- `HttpOnly` refresh cookie set/delete helpers
- CSRF cookie/header validation for cookie-backed routes
- login/refresh/logout route helper functions
- token-claims dependency factory
- stable auth error codes via `X-Auth-Error-Code`

## What Each App Owns

- concrete `User` model
- concrete `RefreshToken` SQLAlchemy model/table
- Alembic migrations
- app roles and permissions
- registration rules
- `/users/me`
- user profile fields

## Backend Contract

The external HTTP behavior this package supports is:

- `POST /auth/login`
  - validates credentials
  - returns access-token JSON
  - sets the refresh token as an `HttpOnly` cookie
  - sets a readable CSRF cookie

- `POST /auth/refresh`
  - reads the refresh token cookie
  - validates the CSRF header against the readable CSRF cookie
  - rotates the refresh token
  - returns access-token JSON
  - sets replacement refresh and CSRF cookies

- `POST /auth/logout`
  - reads the refresh token cookie
  - validates the CSRF header when a refresh cookie is present
  - revokes it if present
  - clears the refresh and CSRF cookies

Normal app endpoints should use:

```http
Authorization: Bearer <access-token>
```

When the package rejects an auth-related request, it preserves the existing HTTP
status behavior and also includes a stable response header:

```http
X-Auth-Error-Code: invalid_refresh_token
```

The exported `AuthErrorCode` values cover invalid credentials, refresh-token
problems, CSRF/origin rejections, and invalid bearer-token cases.

## App Integration Sketch

For the full backend adapter contract, see
[`docs/adapters.md`](../../docs/adapters.md).

Apps provide repository/store adapters:

```python
class AppUserRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_by_email(self, email: str) -> User | None:
        ...

    def get_by_id(self, user_id: UUID) -> User | None:
        ...


class AppRefreshTokenStore:
    def __init__(self, db: Session):
        self.db = db

    def create(self, *, user_id: UUID, token_hash: str, expires_at: datetime) -> None:
        self.db.add(RefreshToken(...))

    def get_by_hash(self, token_hash: str) -> RefreshToken | None:
        ...

    def revoke(self, token: RefreshToken) -> None:
        token.revoked_at = datetime.now(timezone.utc)

    def commit(self) -> None:
        self.db.commit()
```

Then routes delegate to package helpers:

```python
@router.post("/login", response_model=TokenResponse)
def login(
    request: Request,
    response: Response,
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db),
):
    return login_with_password(
        form_data=form_data,
        request=request,
        response=response,
        user_repository=AppUserRepository(db),
        refresh_store=AppRefreshTokenStore(db),
        config=get_cookie_auth_config(),
    )
```

## Security Notes

- Use `HttpOnly` refresh cookies.
- Use `Secure` cookies in production HTTPS.
- Keep access tokens short-lived.
- Keep refresh tokens server-side hashed.
- Rotate refresh tokens on every refresh.
- Use explicit CORS origins when credentialed requests are allowed.
- Keep CSRF protection enabled for browser apps. The default helper checks
  `Sec-Fetch-Site`, validates configured `Origin` values when present, and
  requires a double-submit CSRF cookie/header on refresh/logout.
- Prefer a dedicated trusted-origin setting in each app, separate from CORS.
  Blue Farm uses `CSRF_TRUSTED_ORIGINS` and falls back to `CORS_ALLOW_ORIGINS`
  when the dedicated setting is empty.
- The readable CSRF cookie is not a secret. Its purpose is to prove that the
  calling JavaScript can read cookies for the first-party app origin.
- Same-site deployments are simplest. Cross-site deployments need a cookie
  domain/path strategy that lets the frontend read the CSRF cookie.
- If browser clients need to read `X-Auth-Error-Code` on cross-origin requests,
  expose that header in your CORS middleware or reverse proxy configuration.

## Using From This Repository

Install from this mono-repo with a Git dependency:

```text
fastapi-cookie-auth @ git+https://github.com/SensawayDev/cookie-auth-kit.git@v0.2.0#subdirectory=packages/fastapi_cookie_auth
```

Run local checks:

```bash
python -m pip install -e ".[test]"
python -m pytest
```

Keep this package focused on generic auth mechanics. App-owned user models,
roles, permissions, migrations, and registration rules belong in each consuming
FastAPI app.
