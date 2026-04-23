from __future__ import annotations

from collections.abc import Mapping
from typing import Annotated
from uuid import UUID

from fastapi import Cookie, Depends, FastAPI, HTTPException, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordRequestForm
from fastapi_cookie_auth import (
    StatusResponse,
    TokenResponse,
    create_current_claims_dependency,
)
from fastapi_cookie_auth.router import (
    login_with_password,
    logout_from_cookie,
    refresh_from_cookie,
)

from app.config import PACKAGE_VERSION, get_allowed_origins, get_cookie_auth_config
from app.models import ExampleUser, UserResponse
from app.store import (
    DEMO_EMAIL,
    InMemoryRefreshTokenStore,
    InMemoryUserRepository,
    build_demo_users,
)

COOKIE_AUTH_CONFIG = get_cookie_auth_config()
USER_REPOSITORY = InMemoryUserRepository(build_demo_users())
REFRESH_TOKEN_STORE = InMemoryRefreshTokenStore()
CURRENT_CLAIMS = create_current_claims_dependency(
    COOKIE_AUTH_CONFIG,
    token_url="/auth/login",
)

app = FastAPI(
    title="fastapi-cookie-auth example",
    version=PACKAGE_VERSION,
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=get_allowed_origins(),
    allow_credentials=True,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)


def get_user_repository() -> InMemoryUserRepository:
    return USER_REPOSITORY


def get_refresh_token_store() -> InMemoryRefreshTokenStore:
    return REFRESH_TOKEN_STORE


def _claims_for_user(user: ExampleUser) -> Mapping[str, object]:
    return {"role": user.role}


def _load_user_from_claims(
    claims: Mapping[str, object],
    user_repository: InMemoryUserRepository,
) -> ExampleUser:
    subject = claims.get("sub")
    if not isinstance(subject, str):
        raise HTTPException(status_code=401, detail="Invalid token payload")

    try:
        user_id = UUID(subject)
    except ValueError as error:
        raise HTTPException(status_code=401, detail="Invalid token payload") from error

    user = user_repository.get_by_id(user_id)
    if not user or not user.is_active:
        raise HTTPException(status_code=401, detail="User inactive")
    return user


@app.get("/")
def read_root() -> dict[str, object]:
    return {
        "package": "fastapi-cookie-auth",
        "package_version": PACKAGE_VERSION,
        "demo_credentials": {
            "email": DEMO_EMAIL,
        },
        "routes": [
            "/auth/login",
            "/auth/refresh",
            "/auth/logout",
            "/users/me",
        ],
    }


@app.post("/auth/login", response_model=TokenResponse)
def login(
    request: Request,
    response: Response,
    form_data: Annotated[OAuth2PasswordRequestForm, Depends()],
    user_repository: Annotated[InMemoryUserRepository, Depends(get_user_repository)],
    refresh_store: Annotated[
        InMemoryRefreshTokenStore,
        Depends(get_refresh_token_store),
    ],
) -> TokenResponse:
    return login_with_password(
        form_data=form_data,
        request=request,
        response=response,
        user_repository=user_repository,
        refresh_store=refresh_store,
        config=COOKIE_AUTH_CONFIG,
        extra_claims_for_user=_claims_for_user,
    )


@app.post("/auth/refresh", response_model=TokenResponse)
def refresh(
    request: Request,
    response: Response,
    user_repository: Annotated[InMemoryUserRepository, Depends(get_user_repository)],
    refresh_store: Annotated[
        InMemoryRefreshTokenStore,
        Depends(get_refresh_token_store),
    ],
    refresh_token: Annotated[
        str | None,
        Cookie(alias=COOKIE_AUTH_CONFIG.refresh_cookie_name),
    ] = None,
) -> TokenResponse:
    return refresh_from_cookie(
        refresh_token=refresh_token,
        request=request,
        response=response,
        user_repository=user_repository,
        refresh_store=refresh_store,
        config=COOKIE_AUTH_CONFIG,
        extra_claims_for_user=_claims_for_user,
    )


@app.post("/auth/logout", response_model=StatusResponse)
def logout(
    request: Request,
    response: Response,
    refresh_store: Annotated[
        InMemoryRefreshTokenStore,
        Depends(get_refresh_token_store),
    ],
    refresh_token: Annotated[
        str | None,
        Cookie(alias=COOKIE_AUTH_CONFIG.refresh_cookie_name),
    ] = None,
) -> StatusResponse:
    return logout_from_cookie(
        refresh_token=refresh_token,
        request=request,
        response=response,
        refresh_store=refresh_store,
        config=COOKIE_AUTH_CONFIG,
    )


@app.get("/users/me", response_model=UserResponse)
def read_current_user(
    claims: Annotated[dict[str, object], Depends(CURRENT_CLAIMS)],
    user_repository: Annotated[InMemoryUserRepository, Depends(get_user_repository)],
) -> UserResponse:
    user = _load_user_from_claims(claims, user_repository)
    return UserResponse(
        id=user.id,
        email=user.email,
        display_name=user.display_name,
        role=user.role,
    )
