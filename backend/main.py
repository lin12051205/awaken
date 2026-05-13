from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from api.auth import router as auth_router
from api.chat import router as chat_router
from api.user import router as user_router
from api.debug import router as debug_router

app = FastAPI(title="Awaken API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # restrict to app domain in production
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)
app.include_router(chat_router)
app.include_router(user_router)
app.include_router(debug_router)


@app.get("/health")
async def health():
    return {"status": "ok", "service": "awaken-api"}
