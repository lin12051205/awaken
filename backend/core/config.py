from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    anthropic_api_key: str
    # Firebase Admin SDK — paste the service account JSON as a single-line string
    firebase_credentials_json: str
    # Our own JWT for API sessions
    jwt_secret: str
    jwt_expire_hours: int = 720  # 30 days — long enough that re-auth is rare

    # Business logic
    trial_days: int = 3
    trial_daily_limit: int = 12
    paid_daily_limit: int = 24
    haiku_model: str = "claude-haiku-4-5-20251001"

    class Config:
        env_file = ".env"


settings = Settings()
