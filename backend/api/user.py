"""User status + trial summary."""
from datetime import date, datetime, timezone

from fastapi import APIRouter, Depends
from pydantic import BaseModel

from core.config import settings
from core.database import get_db
from core.security import verify_access_token
from services.usage import is_trial_expired_for_user
from services.anthropic_proxy import call_claude

router = APIRouter(prefix="/user", tags=["user"])


class UserStatusResponse(BaseModel):
    user_id: str
    plan: str
    trial_started_at: str | None
    daily_count: int
    daily_limit: int
    is_trial_expired: bool
    total_conversations: int


class ConversationItem(BaseModel):
    role: str
    content: str


class TrialSummaryRequest(BaseModel):
    conversations: list[ConversationItem]


class TrialSummaryResponse(BaseModel):
    summary: str


@router.get("/status", response_model=UserStatusResponse)
async def get_status(user_id: str = Depends(verify_access_token)):
    db = get_db()
    user_ref = db.collection("users").document(user_id)
    user_doc = user_ref.get()
    if not user_doc.exists:
        from fastapi import HTTPException
        raise HTTPException(404, "User not found")
    user = user_doc.to_dict()

    # Reset if new day
    today = date.today().isoformat()
    if user.get("daily_reset_date") != today:
        user_ref.update({"daily_count": 0, "daily_reset_date": today})
        user["daily_count"] = 0

    expired = is_trial_expired_for_user(user)
    plan = user.get("plan", "trial")
    limit = settings.paid_daily_limit if plan == "paid" else settings.trial_daily_limit

    return UserStatusResponse(
        user_id=user_id,
        plan=plan,
        trial_started_at=user.get("trial_started_at"),
        daily_count=user.get("daily_count", 0),
        daily_limit=limit,
        is_trial_expired=expired,
        total_conversations=user.get("total_conversations", 0),
    )


@router.post("/trial-summary", response_model=TrialSummaryResponse)
async def generate_trial_summary(
    req: TrialSummaryRequest,
    user_id: str = Depends(verify_access_token),
):
    if not req.conversations:
        return TrialSummaryResponse(
            summary="您在試用期間與 AI 董事會進行了深入對話，探索了生活中的重要決策。"
        )

    transcript_lines = []
    for msg in req.conversations[-40:]:
        prefix = "用戶" if msg.role == "user" else "董事"
        transcript_lines.append(f"{prefix}：{msg.content[:200]}")
    transcript = "\n".join(transcript_lines)

    system = (
        "你是一個摘要助手。根據以下對話記錄，用繁體中文寫一段 50 字以內的個人化總結，"
        "說明這位用戶在試用期間主要討論了什麼、獲得了什麼啟發。語氣溫暖、正向、鼓勵。"
        "只輸出摘要文字，不要其他內容。"
    )
    messages = [{"role": "user", "content": f"對話記錄：\n{transcript}"}]
    summary = await call_claude(system=system, messages=messages, max_tokens=200)
    return TrialSummaryResponse(summary=summary.strip())


@router.post("/upgrade")
async def notify_upgrade(user_id: str = Depends(verify_access_token)):
    """Called by iOS after StoreKit purchase confirmed."""
    db = get_db()
    db.collection("users").document(user_id).update({
        "plan": "paid",
        "paid_started_at": datetime.now(timezone.utc).isoformat(),
    })
    return {"status": "upgraded", "plan": "paid"}
