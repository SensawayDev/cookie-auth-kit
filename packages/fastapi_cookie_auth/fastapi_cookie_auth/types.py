from __future__ import annotations

from datetime import datetime
from typing import Protocol
from uuid import UUID


class AuthUser(Protocol):
    id: UUID
    email: str
    password_hash: str
    is_active: bool


class UserRepository(Protocol):
    def get_by_email(self, email: str) -> AuthUser | None: ...

    def get_by_id(self, user_id: UUID) -> AuthUser | None: ...


class RefreshTokenRecord(Protocol):
    user_id: UUID
    token_hash: str
    expires_at: datetime
    revoked_at: datetime | None


class RefreshTokenStore(Protocol):
    def create(
        self,
        *,
        user_id: UUID,
        token_hash: str,
        expires_at: datetime,
    ) -> None: ...

    def get_by_hash(self, token_hash: str) -> RefreshTokenRecord | None: ...

    def revoke(self, token: RefreshTokenRecord) -> None: ...

    def commit(self) -> None: ...
