from __future__ import annotations

import secrets

from fastapi import Request, Response

from fastapi_cookie_auth.config import CookieAuthConfig
from fastapi_cookie_auth.errors import AuthErrorCode, auth_http_exception


def new_csrf_token() -> str:
    return secrets.token_urlsafe(32)


def set_csrf_cookie(response: Response, config: CookieAuthConfig) -> str | None:
    if not config.csrf_protection_enabled:
        return None

    token = new_csrf_token()
    response.set_cookie(
        key=config.csrf_cookie_name,
        value=token,
        max_age=int(config.refresh_token_ttl.total_seconds()),
        httponly=False,
        secure=config.refresh_cookie_secure,
        samesite=config.refresh_cookie_samesite,
        path=config.csrf_cookie_path,
    )
    return token


def clear_csrf_cookie(response: Response, config: CookieAuthConfig) -> None:
    if not config.csrf_protection_enabled:
        return

    response.delete_cookie(
        key=config.csrf_cookie_name,
        secure=config.refresh_cookie_secure,
        samesite=config.refresh_cookie_samesite,
        path=config.csrf_cookie_path,
    )


def validate_csrf_request(
    request: Request,
    config: CookieAuthConfig,
    *,
    require_token: bool,
) -> None:
    if not config.csrf_protection_enabled:
        return

    _validate_fetch_metadata(request)
    _validate_origin(request, config)
    if require_token:
        _validate_double_submit_token(request, config)


def _validate_fetch_metadata(request: Request) -> None:
    fetch_site = request.headers.get("sec-fetch-site")
    if fetch_site == "cross-site":
        raise auth_http_exception(
            status_code=403,
            detail="Cross-site request rejected",
            code=AuthErrorCode.CROSS_SITE_REQUEST_REJECTED,
        )


def _validate_origin(request: Request, config: CookieAuthConfig) -> None:
    origin = request.headers.get("origin")
    if not origin or not config.trusted_origins:
        return
    if origin not in config.trusted_origins:
        raise auth_http_exception(
            status_code=403,
            detail="Untrusted request origin",
            code=AuthErrorCode.UNTRUSTED_ORIGIN,
        )


def _validate_double_submit_token(
    request: Request,
    config: CookieAuthConfig,
) -> None:
    header_token = request.headers.get(config.csrf_header_name)
    cookie_token = request.cookies.get(config.csrf_cookie_name)
    if not header_token or not cookie_token:
        raise auth_http_exception(
            status_code=403,
            detail="Missing CSRF token",
            code=AuthErrorCode.MISSING_CSRF_TOKEN,
        )
    if not secrets.compare_digest(header_token, cookie_token):
        raise auth_http_exception(
            status_code=403,
            detail="Invalid CSRF token",
            code=AuthErrorCode.INVALID_CSRF_TOKEN,
        )
