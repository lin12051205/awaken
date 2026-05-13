"""Debug endpoints — list available Anthropic models for the current API key."""
import httpx
from fastapi import APIRouter, HTTPException
from core.config import settings

router = APIRouter(prefix="/debug", tags=["debug"])


@router.get("/models")
async def list_models():
    """Hit Anthropic's GET /v1/models to see which models this API key can access."""
    api_key = settings.anthropic_api_key.strip()
    headers = {
        "x-api-key": api_key,
        "anthropic-version": "2023-06-01",
    }
    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.get("https://api.anthropic.com/v1/models", headers=headers)
        if resp.status_code != 200:
            raise HTTPException(502, f"Anthropic /models error {resp.status_code}: {resp.text}")
        return resp.json()
