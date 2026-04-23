from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from threading import Lock
from uuid import UUID

from fastapi_cookie_auth import hash_password

from app.models import ExampleUser

DEMO_EMAIL = "demo@example.com"
DEMO_PASSWORD = "demo-password"


def build_demo_users() -> list[ExampleUser]:
    return [
        ExampleUser(
            id=UUID("00000000-0000-0000-0000-000000000001"),
            email=DEMO_EMAIL,
            password_hash=hash_password(DEMO_PASSWORD),
            display_name="Demo Farmer",
            role="farm-admin",
        )
    ]


class InMemoryUserRepository:
    def __init__(self, users: list[ExampleUser]) -> None:
        self._users_by_id = {user.id: user for user in users}
        self._users_by_email = {user.email.lower(): user for user in users}

    def get_by_email(self, email: str) -> ExampleUser | None:
        return self._users_by_email.get(email.lower())

    def get_by_id(self, user_id: UUID) -> ExampleUser | None:
        return self._users_by_id.get(user_id)


@dataclass
class InMemoryRefreshTokenRecord:
    user_id: UUID
    token_hash: str
    expires_at: datetime
    revoked_at: datetime | None = None


class InMemoryRefreshTokenStore:
    def __init__(self) -> None:
        self._lock = Lock()
        self._records: list[InMemoryRefreshTokenRecord] = []

    def create(
        self,
        *,
        user_id: UUID,
        token_hash: str,
        expires_at: datetime,
    ) -> None:
        with self._lock:
            self._records.append(
                InMemoryRefreshTokenRecord(
                    user_id=user_id,
                    token_hash=token_hash,
                    expires_at=expires_at,
                )
            )

    def get_by_hash(self, token_hash: str) -> InMemoryRefreshTokenRecord | None:
        with self._lock:
            return next(
                (record for record in self._records if record.token_hash == token_hash),
                None,
            )

    def revoke(self, token: InMemoryRefreshTokenRecord) -> None:
        with self._lock:
            token.revoked_at = datetime.now(timezone.utc)

    def commit(self) -> None:
        # The real package expects explicit persistence boundaries.
        # The in-memory example has no external transaction to flush.
        return None
