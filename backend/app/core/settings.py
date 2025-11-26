import os
from typing import List

# Centralized app settings pulled from environment with safe defaults.
class Settings:
    SECRET_KEY: str = os.environ.get("SECRET_KEY", "CHANGE_ME_PLEASE")
    ALGORITHM: str = os.environ.get("JWT_ALGORITHM", "HS256")
    # Default access token expiry: 1 day (1440 minutes). Can be overridden via env.
    ACCESS_TOKEN_EXPIRE_MINUTES: int = int(os.environ.get("ACCESS_TOKEN_EXPIRE_MINUTES", "1440"))
    LOG_LEVEL: str = os.environ.get("LOG_LEVEL", "INFO")
    ENABLE_SCHEDULER: bool = os.environ.get("ENABLE_SCHEDULER", "true").lower() in ("1", "true", "yes")
    FRONTEND_ORIGINS: List[str] = [
        origin.strip()
        for origin in os.environ.get("FRONTEND_ORIGINS", "").split(",")
        if origin.strip()
    ]


settings = Settings()
