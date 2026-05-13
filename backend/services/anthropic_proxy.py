"""Proxy calls to Anthropic Claude API, keeping the key server-side."""
import httpx
from fastapi import HTTPException
from core.config import settings

ANTHROPIC_URL = "https://api.anthropic.com/v1/messages"


async def call_claude(
    system: str,
    messages: list[dict],
    max_tokens: int = 4096,
    model: str | None = None,
) -> str:
    """
    Call the Anthropic Messages API and return the text response.
    Uses Haiku by default (cost-efficient for all production calls).
    """
    # Strip whitespace/newlines — Vercel env vars sometimes include trailing \n
    api_key = settings.anthropic_api_key.strip()

    headers = {
        "x-api-key": api_key,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
    }

    payload = {
        "model": model or settings.haiku_model,
        "max_tokens": max_tokens,
        "system": system,
        "messages": messages,
    }
    async with httpx.AsyncClient(timeout=60) as client:
        resp = await client.post(ANTHROPIC_URL, json=payload, headers=headers)
        if resp.status_code != 200:
            raise HTTPException(502, f"Anthropic API error {resp.status_code}: {resp.text}")
        data = resp.json()
    return data["content"][0]["text"]
