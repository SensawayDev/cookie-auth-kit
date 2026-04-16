from __future__ import annotations

import hashlib
import secrets
from collections.abc import Callable, Mapping
from dataclasses import dataclass
from datetime import datetime, timezone

from fastapi import HTTPException

from fastapi_cookie_auth.config import CookieAuthConfig
from fastapi_cookie_auth.tokens import create_access_token
from fastapi_cookie_auth.types import AuthUser, RefreshTokenStore, UserRepository


@dataclass(frozen=True)
class IssuedTokens:
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


def new_refresh_token() -> str:
    return secrets.token_urlsafe(48)


def hash_refresh_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def issue_login_tokens(
    *,
    user: AuthUser,
    refresh_store: RefreshTokenStore,
    config: CookieAuthConfig,
    extra_claims: Mapping[str, object] | None = None,
) -> IssuedTokens:
    refresh = _issue_refresh_token(
        user=user,
        refresh_store=refresh_store,
        config=config,
    )
    refresh_store.commit()
    access = create_access_token(
        user_id=str(user.id),
        config=config,
        extra_claims=extra_claims,
    )
    return IssuedTokens(access_token=access, refresh_token=refresh)


def rotate_refresh_token(
    *,
    refresh_token: str | None,
    user_repository: UserRepository,
    refresh_store: RefreshTokenStore,
    config: CookieAuthConfig,
    extra_claims_for_user: Callable[[AuthUser], Mapping[str, object]] | None = None,
) -> IssuedTokens:
    if not refresh_token:
        raise HTTPException(status_code=401, detail="Missing refresh token")

    token_hash = hash_refresh_token(refresh_token)
    stored_refresh = refresh_store.get_by_hash(token_hash)
    if not stored_refresh:
        raise HTTPException(status_code=401, detail="Invalid refresh token")
    if stored_refresh.revoked_at is not None:
        raise HTTPException(status_code=401, detail="Refresh token revoked")
    if stored_refresh.expires_at <= datetime.now(timezone.utc):
        raise HTTPException(status_code=401, detail="Refresh token expired")

    user = user_repository.get_by_id(stored_refresh.user_id)
    if not user or not user.is_active:
        raise HTTPException(status_code=401, detail="User inactive")

    refresh_store.revoke(stored_refresh)
    new_refresh = _issue_refresh_token(
        user=user,
        refresh_store=refresh_store,
        config=config,
    )
    refresh_store.commit()

    access = create_access_token(
        user_id=str(user.id),
        config=config,
        extra_claims=extra_claims_for_user(user) if extra_claims_for_user else None,
    )
    return IssuedTokens(access_token=access, refresh_token=new_refresh)


def revoke_refresh_token(
    *,
    refresh_token: str | None,
    refresh_store: RefreshTokenStore,
) -> None:
    if not refresh_token:
        return

    stored_refresh = refresh_store.get_by_hash(hash_refresh_token(refresh_token))
    if not stored_refresh:
        return
    if stored_refresh.revoked_at is None:
        refresh_store.revoke(stored_refresh)
        refresh_store.commit()


def _issue_refresh_token(
    *,
    user: AuthUser,
    refresh_store: RefreshTokenStore,
    config: CookieAuthConfig,
) -> str:
    refresh = new_refresh_token()
    refresh_store.create(
        user_id=user.id,
        token_hash=hash_refresh_token(refresh),
        expires_at=datetime.now(timezone.utc) + config.refresh_token_ttl,
    )
    return refresh
