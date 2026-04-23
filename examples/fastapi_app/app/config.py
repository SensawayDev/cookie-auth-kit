from __future__ import annotations

import os

from fastapi_cookie_auth import CookieAuthConfig

PACKAGE_VERSION = "0.1.1"
DEFAULT_ALLOWED_ORIGINS = (
    "http://localhost:8080,"
    "http://127.0.0.1:8080,"
    "http://localhost:8000,"
    "http://127.0.0.1:8000"
)


def _split_origins(name: str, default: str) -> list[str]:
    raw_value = os.getenv(name, default)
    return [item.strip() for item in raw_value.split(",") if item.strip()]


def get_allowed_origins() -> list[str]:
    return _split_origins(
        "COOKIE_AUTH_EXAMPLE_ALLOWED_ORIGINS",
        DEFAULT_ALLOWED_ORIGINS,
    )


def get_cookie_auth_config() -> CookieAuthConfig:
    return CookieAuthConfig(
        jwt_secret=os.getenv(
            "COOKIE_AUTH_EXAMPLE_JWT_SECRET",
            "dev-secret-v0.1.1",
        ),
        access_token_minutes=int(
            os.getenv("COOKIE_AUTH_EXAMPLE_ACCESS_TOKEN_MINUTES", "1")
        ),
        refresh_token_days=int(
            os.getenv("COOKIE_AUTH_EXAMPLE_REFRESH_TOKEN_DAYS", "7")
        ),
        refresh_cookie_name="example_refresh_token",
        refresh_cookie_path="/auth",
        refresh_cookie_secure=os.getenv(
            "COOKIE_AUTH_EXAMPLE_REFRESH_COOKIE_SECURE",
            "false",
        ).lower()
        == "true",
        refresh_cookie_samesite="lax",
        csrf_cookie_name="example_csrf_token",
        csrf_cookie_path="/",
        trusted_origins=_split_origins(
            "COOKIE_AUTH_EXAMPLE_TRUSTED_ORIGINS",
            DEFAULT_ALLOWED_ORIGINS,
        ),
    )
