from __future__ import annotations

from datetime import datetime, timezone
from typing import Mapping

from fastapi import HTTPException
from jose import JWTError, jwt

from fastapi_cookie_auth.config import CookieAuthConfig

RESERVED_ACCESS_TOKEN_CLAIMS = frozenset({"sub", "typ", "iat", "exp"})


def create_access_token(
    *,
    user_id: str,
    config: CookieAuthConfig,
    extra_claims: Mapping[str, object] | None = None,
) -> str:
    now = datetime.now(timezone.utc)
    payload = {
        "sub": user_id,
        "typ": "access",
        "iat": int(now.timestamp()),
        "exp": int((now + config.access_token_ttl).timestamp()),
    }
    if extra_claims:
        reserved_claims = RESERVED_ACCESS_TOKEN_CLAIMS.intersection(extra_claims)
        if reserved_claims:
            blocked = ", ".join(sorted(reserved_claims))
            raise ValueError(f"extra_claims may not override reserved claims: {blocked}")
        payload.update(extra_claims)
    return jwt.encode(payload, config.jwt_secret, algorithm=config.jwt_alg)


def decode_access_token(token: str, config: CookieAuthConfig) -> dict[str, object]:
    try:
        payload = jwt.decode(token, config.jwt_secret, algorithms=[config.jwt_alg])
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")

    if payload.get("typ") != "access":
        raise HTTPException(status_code=401, detail="Invalid token type")
    if not payload.get("sub"):
        raise HTTPException(status_code=401, detail="Invalid token payload")
    return payload
