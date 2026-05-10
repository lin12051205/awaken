"""JWT helpers for our own session tokens (not Apple's)."""
from datetime import datetime, timedelta, timezone

from jose import jwt, JWTError
from fastapi import HTTPException, Header

from core.config import settings

ALGORITHM = "HS256"


def create_access_token(user_id: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(hours=settings.jwt_expire_hours)
    payload = {"sub": user_id, "exp": expire}
    return jwt.encode(payload, settings.jwt_secret, algorithm=ALGORITHM)


def verify_access_token(authorization: str = Header(...)) -> str:
    """FastAPI dependency — returns user_id (uuid) from Bearer token."""
    if not authorization.startswith("Bearer "):
        raise HTTPException(401, "Missing Bearer token")
    token = authorization[7:]
    try:
        payload = jwt.decode(token, settings.jwt_secret, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        if not user_id:
            raise HTTPException(401, "Invalid token")
        return user_id
    except JWTError:
        raise HTTPException(401, "Token expired or invalid")
