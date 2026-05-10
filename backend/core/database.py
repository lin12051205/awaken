"""Firebase Admin SDK initializer — Firestore client."""
import json
import firebase_admin
from firebase_admin import credentials, firestore
from core.config import settings

_initialized = False
_db = None


def get_db():
    global _initialized, _db
    if not _initialized:
        cred_dict = json.loads(settings.firebase_credentials_json)
        cred = credentials.Certificate(cred_dict)
        firebase_admin.initialize_app(cred)
        _initialized = True
    if _db is None:
        _db = firestore.client()
    return _db


def get_auth():
    get_db()  # ensure initialized
    from firebase_admin import auth
    return auth
