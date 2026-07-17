from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import Optional
import json


class Settings(BaseSettings):
    PROJECT_NAME: str = "FlyAI Gateway"
    API_V1_STR: str = "/api/v1"

    # ── CORS ──────────────────────────────────────────────────────────────────
    # Set via env var as JSON array: '["https://flyai.vercel.app"]'
    # or comma-separated: "https://flyai.vercel.app,http://localhost:3000"
    BACKEND_CORS_ORIGINS: str = (
        '["http://localhost:3000","https://localhost:3000","http://localhost:8000"]'
    )

    @property
    def cors_origins(self) -> list[str]:
        raw = self.BACKEND_CORS_ORIGINS.strip()
        if raw.startswith("["):
            return json.loads(raw)
        return [o.strip() for o in raw.split(",") if o.strip()]

    # ── Database ───────────────────────────────────────────────────────────────
    DATABASE_URL: str = "postgresql://postgres:postgres@localhost:5432/postgres"

    # ── Supabase ───────────────────────────────────────────────────────────────
    SUPABASE_URL: Optional[str] = None
    SUPABASE_KEY: Optional[str] = None       # service_role key (server-side only)

    # ── AI API Keys ────────────────────────────────────────────────────────────
    GEMINI_API_KEY: Optional[str] = None
    GROQ_API_KEY: Optional[str] = None
    MISTRAL_API_KEY: Optional[str] = None

    # ── Redis (Render only — not used on Vercel serverless) ───────────────────
    REDIS_HOST: str = "localhost"
    REDIS_PORT: int = 6379

    # ── Vector DB (Render only) ────────────────────────────────────────────────
    QDRANT_HOST: Optional[str] = None
    QDRANT_API_KEY: Optional[str] = None

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore",
    )


settings = Settings()
