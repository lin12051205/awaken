"""Daily conversation count tracking and limit enforcement."""
from datetime import date, datetime

from fastapi import HTTPException
from core.config import settings


def _today_str() -> str:
    return date.today().isoformat()


def is_trial_expired_for_user(user: dict) -> bool:
    if user.get("plan") == "paid":
        return False
    trial_started = user.get("trial_started_at")
    if not trial_started:
        return False
    start = datetime.fromisoformat(trial_started).date()
    return (date.today() - start).days >= settings.trial_days


def check_and_increment(db, user_id: str) -> dict:
    """
    Validates the user can send one more message today.
    Increments daily_count in Firestore.
    Returns updated user dict.
    Raises 402 if limit exceeded or trial expired.
    """
    user_ref = db.collection("users").document(user_id)
    user_doc = user_ref.get()
    if not user_doc.exists:
        raise HTTPException(404, "User not found")

    user = user_doc.to_dict()
    today = _today_str()

    # Reset daily count if new day
    if user.get("daily_reset_date") != today:
        user_ref.update({"daily_count": 0, "daily_reset_date": today})
        user["daily_count"] = 0

    plan = user.get("plan", "trial")

    if plan != "paid" and is_trial_expired_for_user(user):
        raise HTTPException(402, "trial_expired")

    limit = settings.paid_daily_limit if plan == "paid" else settings.trial_daily_limit

    if user.get("daily_count", 0) >= limit:
        raise HTTPException(402, "daily_limit_reached")

    # Increment
    new_count = user.get("daily_count", 0) + 1
    new_total = user.get("total_conversations", 0) + 1
    user_ref.update({
        "daily_count": new_count,
        "total_conversations": new_total,
    })
    user["daily_count"] = new_count
    user["total_conversations"] = new_total
    return user
