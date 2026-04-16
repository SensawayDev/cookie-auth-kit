from fastapi import Response

from fastapi_cookie_auth.config import CookieAuthConfig
from fastapi_cookie_auth.csrf import clear_csrf_cookie, set_csrf_cookie


def set_refresh_cookie(
    response: Response,
    refresh_token: str,
    config: CookieAuthConfig,
) -> None:
    response.set_cookie(
        key=config.refresh_cookie_name,
        value=refresh_token,
        max_age=int(config.refresh_token_ttl.total_seconds()),
        httponly=True,
        secure=config.refresh_cookie_secure,
        samesite=config.refresh_cookie_samesite,
        path=config.refresh_cookie_path,
    )
    set_csrf_cookie(response, config)


def clear_refresh_cookie(response: Response, config: CookieAuthConfig) -> None:
    response.delete_cookie(
        key=config.refresh_cookie_name,
        httponly=True,
        secure=config.refresh_cookie_secure,
        samesite=config.refresh_cookie_samesite,
        path=config.refresh_cookie_path,
    )
    clear_csrf_cookie(response, config)
