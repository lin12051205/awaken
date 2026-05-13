"""Chat proxy — keeps Anthropic API key server-side."""
import traceback
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from core.database import get_db
from core.security import verify_access_token
from services.usage import check_and_increment
from services.anthropic_proxy import call_claude
from core.config import settings

router = APIRouter(prefix="/chat", tags=["chat"])


class ChatMessage(BaseModel):
    role: str
    content: str


class ChatRequest(BaseModel):
    system_prompt: str
    messages: list[ChatMessage]
    max_tokens: int = 4096
    # model is intentionally NOT accepted from client — always use Haiku server-side


class ChatResponse(BaseModel):
    reply: str
    daily_count: int
    daily_limit: int


@router.post("", response_model=ChatResponse)
async def chat(
    req: ChatRequest,
    user_id: str = Depends(verify_access_token),
):
    try:
        db = get_db()
        user = check_and_increment(db, user_id)

        plan = user.get("plan", "trial")
        limit = settings.paid_daily_limit if plan == "paid" else settings.trial_daily_limit

        reply = await call_claude(
            system=req.system_prompt,
            messages=[m.model_dump() for m in req.messages],
            max_tokens=req.max_tokens,
            model=settings.haiku_model,  # always Haiku, never overridable by client
        )

        return ChatResponse(
            reply=reply,
            daily_count=user["daily_count"],
            daily_limit=limit,
        )
    except HTTPException:
        raise  # let FastAPI handle 401/402/404 etc. normally
    except Exception as e:
        tb = traceback.format_exc()
        raise HTTPException(500, f"{type(e).__name__}: {e}\n\nTraceback:\n{tb}")
