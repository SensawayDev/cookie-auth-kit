from fastapi import Depends
from fastapi.security import OAuth2PasswordBearer

from fastapi_cookie_auth.config import CookieAuthConfig
from fastapi_cookie_auth.tokens import decode_access_token


def create_current_claims_dependency(
    config: CookieAuthConfig,
    *,
    token_url: str = "auth/login",
):
    oauth2_scheme = OAuth2PasswordBearer(tokenUrl=token_url)

    def get_current_claims(token: str = Depends(oauth2_scheme)) -> dict[str, object]:
        return decode_access_token(token, config)

    return get_current_claims
