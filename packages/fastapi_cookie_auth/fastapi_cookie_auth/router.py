from __future__ import annotations

from collections.abc import Callable, Mapping

from fastapi import HTTPException, Request, Response
from fastapi.security import OAuth2PasswordRequestForm

from fastapi_cookie_auth.config import CookieAuthConfig
from fastapi_cookie_auth.cookies import clear_refresh_cookie, set_refresh_cookie
from fastapi_cookie_auth.csrf import validate_csrf_request
from fastapi_cookie_auth.password import verify_password
from fastapi_cookie_auth.refresh_tokens import (
    issue_login_tokens,
    revoke_refresh_token,
    rotate_refresh_token,
)
from fastapi_cookie_auth.schemas import StatusResponse, TokenResponse
from fastapi_cookie_auth.types import AuthUser, RefreshTokenStore, UserRepository


def login_with_password(
    *,
    form_data: OAuth2PasswordRequestForm,
    request: Request,
    response: Response,
    user_repository: UserRepository,
    refresh_store: RefreshTokenStore,
    config: CookieAuthConfig,
    extra_claims_for_user: Callable[[AuthUser], Mapping[str, object]] | None = None,
) -> TokenResponse:
    validate_csrf_request(request, config, require_token=False)

    normalized_email = form_data.username.lower().strip()
    user = user_repository.get_by_email(normalized_email)
    if not user or not user.is_active:
        raise HTTPException(status_code=401, detail="Invalid credentials")
    if not verify_password(form_data.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    tokens = issue_login_tokens(
        user=user,
        refresh_store=refresh_store,
        config=config,
        extra_claims=extra_claims_for_user(user) if extra_claims_for_user else None,
    )
    set_refresh_cookie(response, tokens.refresh_token, config)
    return TokenResponse(access_token=tokens.access_token, token_type=tokens.token_type)


def refresh_from_cookie(
    *,
    refresh_token: str | None,
    request: Request,
    response: Response,
    user_repository: UserRepository,
    refresh_store: RefreshTokenStore,
    config: CookieAuthConfig,
    extra_claims_for_user: Callable[[AuthUser], Mapping[str, object]] | None = None,
) -> TokenResponse:
    validate_csrf_request(request, config, require_token=True)

    tokens = rotate_refresh_token(
        refresh_token=refresh_token,
        user_repository=user_repository,
        refresh_store=refresh_store,
        config=config,
        extra_claims_for_user=extra_claims_for_user,
    )
    set_refresh_cookie(response, tokens.refresh_token, config)
    return TokenResponse(access_token=tokens.access_token, token_type=tokens.token_type)


def logout_from_cookie(
    *,
    refresh_token: str | None,
    request: Request,
    response: Response,
    refresh_store: RefreshTokenStore,
    config: CookieAuthConfig,
) -> StatusResponse:
    validate_csrf_request(request, config, require_token=refresh_token is not None)

    revoke_refresh_token(refresh_token=refresh_token, refresh_store=refresh_store)
    clear_refresh_cookie(response, config)
    return StatusResponse()
