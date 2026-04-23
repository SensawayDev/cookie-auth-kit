# Backend Adapter Protocols

This document explains the FastAPI-side adapter contracts used by
`fastapi-cookie-auth` `0.2.0`.

The package is intentionally app-agnostic. It does not define a concrete user
model, ORM model, database session, or migration. Each consuming app supplies
small adapters that satisfy the structural protocols in
`packages/fastapi_cookie_auth/fastapi_cookie_auth/types.py`.

## Ownership Boundary

The package owns:

- password verification
- access-token creation and validation
- refresh-token generation, hashing, rotation, and revocation rules
- CSRF and origin validation helpers
- auth route helper orchestration

The consuming app owns:

- the concrete `User` model
- the concrete refresh-token table/model
- migrations
- the database session lifecycle
- transaction boundaries beyond the auth helper `commit()` calls
- `/users/me` and all application-specific profile fields

Do not move roles, permissions, tenant rules, registration policy, password
reset, or other app-specific identity concerns into these adapters.

## `AuthUser`

`AuthUser` is a structural protocol. Your concrete user object does not need to
inherit from anything as long as it exposes the required attributes:

```python
class AuthUser(Protocol):
    id: UUID
    email: str
    password_hash: str
    is_active: bool
```

Expected semantics:

- `id`: stable unique user identifier. The package serializes this into the JWT
  `sub` claim as a string.
- `email`: normalized login identifier used by `login_with_password`. The route
  helper lowercases and trims the submitted username before calling
  `get_by_email`.
- `password_hash`: app-stored password hash suitable for
  `fastapi_cookie_auth.verify_password`.
- `is_active`: when false, login and refresh should be rejected with `401`.

The package does not require SQLAlchemy models specifically. Dataclasses, ORM
entities, or wrapper objects are all acceptable if they expose the same shape.

## `UserRepository`

`UserRepository` resolves users for login and refresh:

```python
class UserRepository(Protocol):
    def get_by_email(self, email: str) -> AuthUser | None: ...

    def get_by_id(self, user_id: UUID) -> AuthUser | None: ...
```

Behavior requirements:

- `get_by_email` should return the user for the normalized email or `None`.
- `get_by_id` should return the user for the refresh/access token subject or
  `None`.
- Both methods should be read-only. They should not mutate the database or
  perform implicit commits.

Practical guidance:

- Normalize email consistently in the app. The helper already lowercases and
  trims the submitted login value, so your storage lookup should match that.
- If your app needs tenant-aware lookup, keep that policy in the app layer or
  a wrapping repository. Do not change the reusable package to understand
  tenants.

Minimal example:

```python
class AppUserRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_by_email(self, email: str) -> User | None:
        return self.db.scalar(select(User).where(User.email == email))

    def get_by_id(self, user_id: UUID) -> User | None:
        return self.db.get(User, user_id)
```

## `RefreshTokenRecord`

`RefreshTokenRecord` is the persisted representation of one refresh token hash:

```python
class RefreshTokenRecord(Protocol):
    user_id: UUID
    token_hash: str
    expires_at: datetime
    revoked_at: datetime | None
```

Expected semantics:

- `user_id`: identifies the user that owns the refresh token.
- `token_hash`: SHA-256 hash of the opaque refresh token string.
- `expires_at`: absolute expiry timestamp for the record.
- `revoked_at`: `None` until the token is revoked; non-`None` means the token
  can no longer be used.

The package only needs these fields. Your concrete model may include more app
fields such as `created_at`, `ip_address`, `user_agent`, or `device_label`, but
those stay app-owned.

## `RefreshTokenStore`

`RefreshTokenStore` owns persistence operations for refresh token hashes:

```python
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
```

Method expectations:

- `create`: stage or persist a new refresh-token record. The package passes a
  hashed token, not the raw token value.
- `get_by_hash`: return the matching record by hash or `None`.
- `revoke`: mark the given record as revoked. This should not create a new
  record or change ownership.
- `commit`: flush the changes made by the package operation.

Minimal example:

```python
class AppRefreshTokenStore:
    def __init__(self, db: Session):
        self.db = db

    def create(
        self,
        *,
        user_id: UUID,
        token_hash: str,
        expires_at: datetime,
    ) -> None:
        self.db.add(
            RefreshToken(
                user_id=user_id,
                token_hash=token_hash,
                expires_at=expires_at,
            )
        )

    def get_by_hash(self, token_hash: str) -> RefreshToken | None:
        return self.db.scalar(
            select(RefreshToken).where(RefreshToken.token_hash == token_hash)
        )

    def revoke(self, token: RefreshToken) -> None:
        token.revoked_at = datetime.now(timezone.utc)

    def commit(self) -> None:
        self.db.commit()
```

## Commit And Transaction Behavior

The package expects the refresh-token store to make persistence explicit.

Current helper behavior:

- `issue_login_tokens(...)`
  - calls `create(...)` for the new refresh token
  - then calls `commit()`
- `rotate_refresh_token(...)`
  - loads the current token
  - calls `revoke(...)` on the old token
  - calls `create(...)` for the replacement token
  - then calls `commit()`
- `revoke_refresh_token(...)`
  - calls `revoke(...)` when a matching non-revoked token exists
  - then calls `commit()`

What this means for adapter authors:

- `create` and `revoke` should stage changes in the current unit of work.
- `commit` should persist those staged changes atomically for that auth
  operation.
- Do not rely on implicit ORM autoflush behavior as the only persistence
  boundary. The package already assumes `commit()` is the authoritative write.

If your app prefers a larger transaction wrapper, the adapter still needs to
present the same semantics to the package. The easiest option is usually to keep
`commit()` backed by the session or repository unit of work that already owns
the refresh-token table.

## `expires_at` Must Be Timezone-Aware

Use timezone-aware UTC datetimes for `expires_at` and `revoked_at`.

Recommended pattern:

```python
from datetime import datetime, timezone

datetime.now(timezone.utc)
```

Why this matters:

- the package compares `expires_at` against `datetime.now(timezone.utc)`
- mixing naive and aware datetimes raises runtime errors in Python
- UTC storage avoids DST and local-time ambiguity

Recommendation:

- store UTC timestamps in the database
- return timezone-aware values from your ORM or adapter
- avoid naive `datetime.utcnow()` values unless your app converts them into
  aware UTC datetimes before the package sees them

## Why Only Refresh-Token Hashes Are Stored

The package generates refresh tokens as opaque random strings and expects the
backend to persist only their hashes.

Rationale:

- a database leak should not directly reveal live refresh tokens
- the browser cookie still holds the raw token, so the server can hash the
  presented value and compare it against the stored hash
- this keeps refresh-token storage closer to password-storage practice: compare
  derived values instead of storing bearer secrets in plaintext

The package currently uses SHA-256 for refresh-token hashing. Your adapter
should store the hash string exactly as passed into `create(...)` and compare by
the hashed value in `get_by_hash(...)`.

Do not:

- store plaintext refresh tokens
- log raw refresh token values
- expose raw refresh tokens in admin tools or APIs

## Recommended Database Shape

The package does not enforce a schema, but a practical refresh-token table often
includes:

```text
id
user_id
token_hash
expires_at
revoked_at
created_at
```

Optional app-owned fields:

- `last_used_at`
- `created_by_ip`
- `user_agent`
- `device_name`

These optional fields are useful for future session-management features, but
they are not part of the current reusable adapter contract.

## Integration Checklist

- Implement `UserRepository.get_by_email`.
- Implement `UserRepository.get_by_id`.
- Implement `RefreshTokenStore.create`.
- Implement `RefreshTokenStore.get_by_hash`.
- Implement `RefreshTokenStore.revoke`.
- Implement `RefreshTokenStore.commit`.
- Ensure `expires_at` and `revoked_at` are timezone-aware UTC datetimes.
- Store only hashed refresh tokens.
- Keep `/users/me` and user-profile serialization in the app.

## Related Docs

- [Package README](../packages/fastapi_cookie_auth/README.md)
- [Deployment](deployment.md)
- [Security](security.md)
- [FastAPI example app](../examples/fastapi_app/README.md)
