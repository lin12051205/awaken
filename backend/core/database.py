"""Firebase Admin SDK initializer — Firestore client."""
import json
import firebase_admin
from firebase_admin import credentials, firestore
from core.config import settings

_db = None


def _ensure_initialized():
    """Initialize Firebase Admin SDK exactly once per process (safe for Vercel warm reuse)."""
    if firebase_admin._apps:
        return  # Already initialized in this worker process
    cred_dict = json.loads(settings.firebase_credentials_json)
    cred = credentials.Certificate(cred_dict)
    firebase_admin.initialize_app(cred)


def get_db():
    global _db
    _ensure_initialized()
    if _db is None:
        _db = firestore.client()
    return _db


def get_auth():
    _ensure_initialized()
    from firebase_admin import auth
    return auth
