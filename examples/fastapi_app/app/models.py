from __future__ import annotations

from dataclasses import dataclass
from uuid import UUID

from pydantic import BaseModel


@dataclass(frozen=True)
class ExampleUser:
    id: UUID
    email: str
    password_hash: str
    display_name: str
    role: str
    is_active: bool = True


class UserResponse(BaseModel):
    id: UUID
    email: str
    display_name: str
    role: str
