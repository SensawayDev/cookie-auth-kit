from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from http.cookies import SimpleCookie
from types import SimpleNamespace
from uuid import UUID, uuid4

import pytest
from fastapi import Depends, FastAPI, HTTPException, Response
from fastapi.security import OAuth2PasswordRequestForm
from starlette.requests import Request

from fastapi_cookie_auth import (
    AUTH_ERROR_CODE_HEADER,
    AuthErrorCode,
    CookieAuthConfig,
    clear_refresh_cookie,
    create_current_claims_dependency,
    create_access_token,
    decode_access_token,
    hash_password,
    hash_refresh_token,
    issue_login_tokens,
    set_refresh_cookie,
    verify_password,
)
from fastapi_cookie_auth.csrf import validate_csrf_request
from fastapi_cookie_auth.refresh_tokens import rotate_refresh_token
from fastapi_cookie_auth.router import (
    login_with_password,
    logout_from_cookie,
    refresh_from_cookie,
)


def test_hash_password_verifies_argon2_hash():
    hashed = hash_password("secret123")

    assert hashed != "secret123"
    assert verify_password("secret123", hashed) is True
    assert verify_password("wrong", hashed) is False


def test_access_token_round_trip_with_extra_claims():
    config = _config()

    token = create_access_token(
        user_id="user-1",
        config=config,
        extra_claims={"is_superadmin": True},
    )
    payload = decode_access_token(token, config)

    assert payload["sub"] == "user-1"
    assert payload["typ"] == "access"
    assert payload["is_superadmin"] is True


def test_access_token_extra_claims_cannot_override_reserved_claims():
    with pytest.raises(ValueError, match="reserved claims: exp, sub"):
        create_access_token(
            user_id="user-1",
            config=_config(),
            extra_claims={"sub": "other-user", "exp": 9999999999},
        )


def test_refresh_rotation_revokes_old_token_and_issues_new_one():
    config = _config()
    user = _User(id=uuid4(), email="user@example.com")
    users = _UserRepository([user])
    refresh_store = _RefreshTokenStore()
    issued = issue_login_tokens(
        user=user,
        refresh_store=refresh_store,
        config=config,
        extra_claims={"is_superadmin": False},
    )

    rotated = rotate_refresh_token(
        refresh_token=issued.refresh_token,
        user_repository=users,
        refresh_store=refresh_store,
        config=config,
        extra_claims_for_user=lambda _: {"is_superadmin": True},
    )

    assert rotated.access_token
    assert rotated.refresh_token != issued.refresh_token
    assert len(refresh_store.records) == 2
    assert refresh_store.records[0].revoked_at is not None
    assert refresh_store.commits == 2
    payload = decode_access_token(rotated.access_token, config)
    assert payload["is_superadmin"] is True


def test_refresh_rotation_rejects_missing_token():
    with pytest.raises(HTTPException) as error:
        rotate_refresh_token(
            refresh_token=None,
            user_repository=_UserRepository([]),
            refresh_store=_RefreshTokenStore(),
            config=_config(),
        )

    _assert_auth_error(
        error.value,
        status_code=401,
        detail="Missing refresh token",
        code=AuthErrorCode.MISSING_REFRESH_TOKEN,
    )


def test_refresh_rotation_rejects_invalid_token():
    with pytest.raises(HTTPException) as error:
        rotate_refresh_token(
            refresh_token="missing-token",
            user_repository=_UserRepository([]),
            refresh_store=_RefreshTokenStore(),
            config=_config(),
        )

    _assert_auth_error(
        error.value,
        status_code=401,
        detail="Invalid refresh token",
        code=AuthErrorCode.INVALID_REFRESH_TOKEN,
    )


def test_refresh_rotation_rejects_revoked_expired_and_inactive_cases():
    config = _config()
    user = _User(id=uuid4(), email="user@example.com")
    active_users = _UserRepository([user])

    revoked_store = _RefreshTokenStore(
        [
            _RefreshToken(
                user_id=user.id,
                token_hash=hash_refresh_token("revoked-token"),
                expires_at=datetime.now(timezone.utc) + timedelta(days=1),
                revoked_at=datetime.now(timezone.utc),
            )
        ]
    )
    with pytest.raises(HTTPException) as revoked_error:
        rotate_refresh_token(
            refresh_token="revoked-token",
            user_repository=active_users,
            refresh_store=revoked_store,
            config=config,
        )
    _assert_auth_error(
        revoked_error.value,
        status_code=401,
        detail="Refresh token revoked",
        code=AuthErrorCode.REVOKED_REFRESH_TOKEN,
    )

    expired_store = _RefreshTokenStore(
        [
            _RefreshToken(
                user_id=user.id,
                token_hash=hash_refresh_token("expired-token"),
                expires_at=datetime.now(timezone.utc) - timedelta(seconds=1),
            )
        ]
    )
    with pytest.raises(HTTPException) as expired_error:
        rotate_refresh_token(
            refresh_token="expired-token",
            user_repository=active_users,
            refresh_store=expired_store,
            config=config,
        )
    _assert_auth_error(
        expired_error.value,
        status_code=401,
        detail="Refresh token expired",
        code=AuthErrorCode.EXPIRED_REFRESH_TOKEN,
    )

    inactive_user = _User(id=user.id, email=user.email, is_active=False)
    inactive_store = _RefreshTokenStore(
        [
            _RefreshToken(
                user_id=user.id,
                token_hash=hash_refresh_token("inactive-token"),
                expires_at=datetime.now(timezone.utc) + timedelta(days=1),
            )
        ]
    )
    with pytest.raises(HTTPException) as inactive_error:
        rotate_refresh_token(
            refresh_token="inactive-token",
            user_repository=_UserRepository([inactive_user]),
            refresh_store=inactive_store,
            config=config,
        )
    _assert_auth_error(
        inactive_error.value,
        status_code=401,
        detail="User inactive",
        code=AuthErrorCode.INACTIVE_USER,
    )


def test_refresh_cookie_helpers_set_and_clear_cookie():
    config = _config()
    response = Response()

    set_refresh_cookie(response, "refresh-token", config)
    cookies = _response_cookies(response)
    set_cookie = cookies[config.refresh_cookie_name]
    csrf_cookie = cookies[config.csrf_cookie_name]

    assert set_cookie.value == "refresh-token"
    assert set_cookie["httponly"] is True
    assert set_cookie["path"] == "/api/auth"
    assert csrf_cookie.value
    assert csrf_cookie["httponly"] == ""
    assert csrf_cookie["path"] == "/"

    response = Response()
    clear_refresh_cookie(response, config)
    cleared_cookies = _response_cookies(response)
    cleared_cookie = cleared_cookies[config.refresh_cookie_name]
    cleared_csrf_cookie = cleared_cookies[config.csrf_cookie_name]

    assert cleared_cookie.value == ""
    assert cleared_cookie["max-age"] == "0"
    assert cleared_csrf_cookie.value == ""
    assert cleared_csrf_cookie["max-age"] == "0"


def test_csrf_validation_rejects_cross_site_and_mismatched_tokens():
    config = _config()
    token = "csrf-token"

    validate_csrf_request(
        _request(
            headers={
                "origin": "http://localhost",
                "x-csrf-token": token,
            },
            cookies={config.csrf_cookie_name: token},
        ),
        config,
        require_token=True,
    )

    with pytest.raises(HTTPException) as cross_site_error:
        validate_csrf_request(
            _request(
                headers={
                    "sec-fetch-site": "cross-site",
                    "x-csrf-token": token,
                },
                cookies={config.csrf_cookie_name: token},
            ),
            config,
            require_token=True,
        )
    _assert_auth_error(
        cross_site_error.value,
        status_code=403,
        detail="Cross-site request rejected",
        code=AuthErrorCode.CROSS_SITE_REQUEST_REJECTED,
    )

    with pytest.raises(HTTPException) as mismatch_error:
        validate_csrf_request(
            _request(
                headers={"x-csrf-token": "wrong"},
                cookies={config.csrf_cookie_name: token},
            ),
            config,
            require_token=True,
        )
    _assert_auth_error(
        mismatch_error.value,
        status_code=403,
        detail="Invalid CSRF token",
        code=AuthErrorCode.INVALID_CSRF_TOKEN,
    )


def test_csrf_validation_rejects_untrusted_and_missing_tokens():
    config = _config()

    with pytest.raises(HTTPException) as untrusted_error:
        validate_csrf_request(
            _request(
                headers={
                    "origin": "http://malicious.example",
                    "x-csrf-token": "csrf-token",
                },
                cookies={config.csrf_cookie_name: "csrf-token"},
            ),
            config,
            require_token=True,
        )
    _assert_auth_error(
        untrusted_error.value,
        status_code=403,
        detail="Untrusted request origin",
        code=AuthErrorCode.UNTRUSTED_ORIGIN,
    )

    with pytest.raises(HTTPException) as missing_token_error:
        validate_csrf_request(
            _request(),
            config,
            require_token=True,
        )
    _assert_auth_error(
        missing_token_error.value,
        status_code=403,
        detail="Missing CSRF token",
        code=AuthErrorCode.MISSING_CSRF_TOKEN,
    )


def test_router_helpers_login_refresh_and_logout():
    config = _config()
    user = _User(
        id=uuid4(),
        email="user@example.com",
        password_hash=hash_password("secret123"),
    )
    users = _UserRepository([user])
    refresh_store = _RefreshTokenStore()
    response = Response()

    login_token = login_with_password(
        form_data=SimpleNamespace(username=user.email, password="secret123"),
        request=_request(headers={"origin": "http://localhost"}),
        response=response,
        user_repository=users,
        refresh_store=refresh_store,
        config=config,
        extra_claims_for_user=lambda _: {"is_superadmin": False},
    )

    assert login_token.access_token
    response_cookies = _response_cookies(response)
    refresh_cookie = response_cookies[config.refresh_cookie_name].value
    csrf_token = response_cookies[config.csrf_cookie_name].value

    response = Response()
    refreshed_token = refresh_from_cookie(
        refresh_token=refresh_cookie,
        request=_request(
            headers={"x-csrf-token": csrf_token},
            cookies={config.csrf_cookie_name: csrf_token},
        ),
        response=response,
        user_repository=users,
        refresh_store=refresh_store,
        config=config,
        extra_claims_for_user=lambda _: {"is_superadmin": True},
    )

    assert refreshed_token.access_token != login_token.access_token
    response_cookies = _response_cookies(response)
    replacement_cookie = response_cookies[config.refresh_cookie_name].value
    csrf_token = response_cookies[config.csrf_cookie_name].value

    response = Response()
    status = logout_from_cookie(
        refresh_token=replacement_cookie,
        request=_request(
            headers={"x-csrf-token": csrf_token},
            cookies={config.csrf_cookie_name: csrf_token},
        ),
        response=response,
        refresh_store=refresh_store,
        config=config,
    )

    assert status.status == "ok"
    assert _response_cookies(response)[config.refresh_cookie_name].value == ""
    assert refresh_store.records[-1].revoked_at is not None


def test_login_rejects_invalid_credentials_with_stable_code():
    user = _User(
        id=uuid4(),
        email="user@example.com",
        password_hash=hash_password("secret123"),
    )

    with pytest.raises(HTTPException) as error:
        login_with_password(
            form_data=SimpleNamespace(username=user.email, password="wrong"),
            request=_request(headers={"origin": "http://localhost"}),
            response=Response(),
            user_repository=_UserRepository([user]),
            refresh_store=_RefreshTokenStore(),
            config=_config(),
        )

    _assert_auth_error(
        error.value,
        status_code=401,
        detail="Invalid credentials",
        code=AuthErrorCode.INVALID_CREDENTIALS,
    )


def test_fastapi_form_dependency_can_be_registered():
    app = FastAPI()

    @app.post("/auth/login")
    def login(form_data: OAuth2PasswordRequestForm = Depends()) -> dict[str, str]:
        return {"username": form_data.username}

    assert app.routes


def test_current_claims_dependency_is_exported_and_decodes_token():
    config = _config()
    dependency = create_current_claims_dependency(config)
    token = create_access_token(user_id="user-1", config=config)

    claims = dependency(token)

    assert claims["sub"] == "user-1"


def test_decode_access_token_reports_stable_error_codes():
    config = _config()

    with pytest.raises(HTTPException) as invalid_token_error:
        decode_access_token("not-a-jwt", config)
    _assert_auth_error(
        invalid_token_error.value,
        status_code=401,
        detail="Invalid token",
        code=AuthErrorCode.INVALID_ACCESS_TOKEN,
    )

    invalid_type_token = _signed_token(
        config,
        {"sub": "user-1", "typ": "refresh"},
    )
    with pytest.raises(HTTPException) as invalid_type_error:
        decode_access_token(invalid_type_token, config)
    _assert_auth_error(
        invalid_type_error.value,
        status_code=401,
        detail="Invalid token type",
        code=AuthErrorCode.INVALID_TOKEN_TYPE,
    )

    missing_subject_token = _signed_token(config, {"typ": "access"})
    with pytest.raises(HTTPException) as invalid_payload_error:
        decode_access_token(missing_subject_token, config)
    _assert_auth_error(
        invalid_payload_error.value,
        status_code=401,
        detail="Invalid token payload",
        code=AuthErrorCode.INVALID_TOKEN_PAYLOAD,
    )


def _config() -> CookieAuthConfig:
    return CookieAuthConfig(
        jwt_secret="test-secret",
        refresh_cookie_name="refresh_cookie",
        refresh_cookie_path="/api/auth",
        refresh_cookie_secure=False,
        trusted_origins=["http://localhost"],
    )


def _response_cookies(response: Response) -> SimpleCookie:
    cookie = SimpleCookie()
    for name, value in response.raw_headers:
        if name.lower() == b"set-cookie":
            cookie.load(value.decode("latin-1"))
    return cookie


def _request(
    *,
    headers: dict[str, str] | None = None,
    cookies: dict[str, str] | None = None,
) -> Request:
    raw_headers = [
        (name.lower().encode("latin-1"), value.encode("latin-1"))
        for name, value in (headers or {}).items()
    ]
    if cookies:
        raw_headers.append(
            (
                b"cookie",
                "; ".join(
                    f"{name}={value}" for name, value in cookies.items()
                ).encode("latin-1"),
            )
        )
    return Request(
        {
            "type": "http",
            "method": "POST",
            "path": "/auth/refresh",
            "headers": raw_headers,
        }
    )


@dataclass
class _User:
    id: UUID
    email: str
    password_hash: str = "hash"
    is_active: bool = True


@dataclass
class _RefreshToken:
    user_id: UUID
    token_hash: str
    expires_at: datetime
    revoked_at: datetime | None = None


class _UserRepository:
    def __init__(self, users: list[_User]) -> None:
        self._users = users

    def get_by_email(self, email: str) -> _User | None:
        return next((user for user in self._users if user.email == email), None)

    def get_by_id(self, user_id: UUID) -> _User | None:
        return next((user for user in self._users if user.id == user_id), None)


class _RefreshTokenStore:
    def __init__(self, records: list[_RefreshToken] | None = None) -> None:
        self.records = list(records or [])
        self.commits = 0

    def create(
        self,
        *,
        user_id: UUID,
        token_hash: str,
        expires_at: datetime,
    ) -> None:
        self.records.append(
            _RefreshToken(
                user_id=user_id,
                token_hash=token_hash,
                expires_at=expires_at,
            )
        )

    def get_by_hash(self, token_hash: str) -> _RefreshToken | None:
        return next(
            (record for record in self.records if record.token_hash == token_hash),
            None,
        )

    def revoke(self, token: _RefreshToken) -> None:
        token.revoked_at = datetime.now(timezone.utc)

    def commit(self) -> None:
        self.commits += 1


def _assert_auth_error(
    error: HTTPException,
    *,
    status_code: int,
    detail: str,
    code: AuthErrorCode,
) -> None:
    assert error.status_code == status_code
    assert error.detail == detail
    assert error.headers == {AUTH_ERROR_CODE_HEADER: code.value}


def _signed_token(
    config: CookieAuthConfig,
    payload: dict[str, object],
) -> str:
    from jose import jwt

    return jwt.encode(payload, config.jwt_secret, algorithm=config.jwt_alg)
