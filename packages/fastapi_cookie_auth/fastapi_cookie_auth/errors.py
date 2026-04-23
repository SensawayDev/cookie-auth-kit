from __future__ import annotations

from enum import StrEnum

from fastapi import HTTPException

AUTH_ERROR_CODE_HEADER = "X-Auth-Error-Code"


class AuthErrorCode(StrEnum):
    INVALID_CREDENTIALS = "invalid_credentials"
    MISSING_REFRESH_TOKEN = "missing_refresh_token"
    INVALID_REFRESH_TOKEN = "invalid_refresh_token"
    REVOKED_REFRESH_TOKEN = "revoked_refresh_token"
    EXPIRED_REFRESH_TOKEN = "expired_refresh_token"
    INACTIVE_USER = "inactive_user"
    MISSING_CSRF_TOKEN = "missing_csrf_token"
    INVALID_CSRF_TOKEN = "invalid_csrf_token"
    UNTRUSTED_ORIGIN = "untrusted_origin"
    CROSS_SITE_REQUEST_REJECTED = "cross_site_request_rejected"
    INVALID_ACCESS_TOKEN = "invalid_access_token"
    INVALID_TOKEN_TYPE = "invalid_token_type"
    INVALID_TOKEN_PAYLOAD = "invalid_token_payload"


def auth_http_exception(
    *,
    status_code: int,
    detail: str,
    code: AuthErrorCode,
) -> HTTPException:
    return HTTPException(
        status_code=status_code,
        detail=detail,
        headers={AUTH_ERROR_CODE_HEADER: code.value},
    )
