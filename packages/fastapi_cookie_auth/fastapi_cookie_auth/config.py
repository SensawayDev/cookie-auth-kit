from datetime import timedelta

from pydantic import BaseModel, computed_field


class CookieAuthConfig(BaseModel):
    jwt_secret: str
    jwt_alg: str = "HS256"
    access_token_minutes: int = 15
    refresh_token_days: int = 30
    refresh_cookie_name: str = "refresh_token"
    refresh_cookie_path: str = "/auth"
    refresh_cookie_secure: bool = True
    refresh_cookie_samesite: str = "lax"
    csrf_protection_enabled: bool = True
    csrf_cookie_name: str = "cookie_auth_csrf"
    csrf_cookie_path: str = "/"
    csrf_header_name: str = "x-csrf-token"
    trusted_origins: list[str] = []

    @computed_field
    @property
    def access_token_ttl(self) -> timedelta:
        return timedelta(minutes=self.access_token_minutes)

    @computed_field
    @property
    def refresh_token_ttl(self) -> timedelta:
        return timedelta(days=self.refresh_token_days)
