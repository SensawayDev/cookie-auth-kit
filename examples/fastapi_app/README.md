# FastAPI Integration Notes

Each backend app keeps its own user and role model. The reusable package expects
small adapters.

## App-Owned Pieces

```text
app/db/models/user.py
app/db/models/auth.py          # refresh_tokens table
app/modules/auth/adapters.py   # UserRepository + RefreshTokenStore
app/modules/auth/config.py     # map app settings to CookieAuthConfig
app/modules/auth/router.py     # login/refresh/logout routes
app/modules/auth/service.py    # registration, password reset, app rules
app/modules/users/router.py    # /users/me
```

## Route Sketch

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
        extra_claims_for_user=app_claims,
    )
```

## Migration Checklist

- Add a `refresh_tokens` table.
- Store only refresh-token hashes.
- Implement `UserRepository`.
- Implement `RefreshTokenStore`.
- Configure `CookieAuthConfig`.
- Add `/auth/login`, `/auth/refresh`, `/auth/logout`.
- Add app-owned `/users/me`.
- Configure `CORS_ALLOW_ORIGINS` and `CSRF_TRUSTED_ORIGINS`.
