"""
Firebase Sign-In → issue our own JWT.
iOS app uses Firebase Auth (with Apple Sign-In), gets a Firebase ID token,
sends it here. We verify it with Firebase Admin SDK, then issue our own JWT.
"""
from datetime import date, datetime, timezone

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from core.database import get_db, get_auth
from core.security import create_access_token
from services.usage import is_trial_expired_for_user
from core.config import settings

router = APIRouter(prefix="/auth", tags=["auth"])


class FirebaseSignInRequest(BaseModel):
    firebase_id_token: str     # from Firebase Auth on iOS
    full_name: str | None = None


class AuthResponse(BaseModel):
    access_token: str
    user_id: str
    plan: str
    trial_started_at: str | None
    daily_count: int
    daily_limit: int
    is_trial_expired: bool


@router.post("/firebase", response_model=AuthResponse)
async def sign_in_with_firebase(req: FirebaseSignInRequest):
    auth = get_auth()

    # Verify Firebase ID token
    try:
        decoded = auth.verify_id_token(req.firebase_id_token)
    except Exception as e:
        raise HTTPException(401, f"Invalid Firebase token: {e}")

    firebase_uid = decoded["uid"]
    db = get_db()
    user_ref = db.collection("users").document(firebase_uid)
    user_doc = user_ref.get()

    if user_doc.exists:
        user = user_doc.to_dict()
    else:
        # New user — start trial
        now = datetime.now(timezone.utc).isoformat()
        today = date.today().isoformat()
        user = {
            "firebase_uid": firebase_uid,
            "full_name": req.full_name,
            "plan": "trial",
            "trial_started_at": now,
            "paid_started_at": None,
            "daily_count": 0,
            "daily_reset_date": today,
            "total_conversations": 0,
            "created_at": now,
        }
        user_ref.set(user)

    # Reset daily count if new day
    today = date.today().isoformat()
    if user.get("daily_reset_date") != today:
        user_ref.update({"daily_count": 0, "daily_reset_date": today})
        user["daily_count"] = 0

    token = create_access_token(firebase_uid)
    expired = is_trial_expired_for_user(user)
    plan = user.get("plan", "trial")
    limit = settings.paid_daily_limit if plan == "paid" else settings.trial_daily_limit

    return AuthResponse(
        access_token=token,
        user_id=firebase_uid,
        plan=plan,
        trial_started_at=user.get("trial_started_at"),
        daily_count=user.get("daily_count", 0),
        daily_limit=limit,
        is_trial_expired=expired,
    )
