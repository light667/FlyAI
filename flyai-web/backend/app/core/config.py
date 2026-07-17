from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import List, Optional
import json

class Settings(BaseSettings):
    PROJECT_NAME: str = "FlyAI Gateway"
    API_V1_STR: str = "/api/v1"

    # CORS — can be a JSON array string in env: '["https://flyai.vercel.app"]'
    # or a plain comma-separated string handled below
    BACKEND_CORS_ORIGINS: str = (
        '["http://localhost:3000","https://localhost:3000","http://localhost:8000"]'
    )

    @property
    def cors_origins(self) -> List[str]:
        """Parse BACKEND_CORS_ORIGINS whether it is a JSON list or CSV string."""
        raw = self.BACKEND_CORS_ORIGINS.strip()
        if raw.startswith("["):
            return json.loads(raw)
        return [origin.strip() for origin in raw.split(",") if origin.strip()]

    # Database
    DATABASE_URL: str = "postgresql://postgres:postgres@localhost:5432/postgres"

    # Vector DB
    QDRANT_HOST: Optional[str] = None
    QDRANT_API_KEY: Optional[str] = None

    # AI API Keys
    GEMINI_API_KEY: Optional[str] = None
    GROQ_API_KEY: Optional[str] = None
    MISTRAL_API_KEY: Optional[str] = None

    # Supabase
    SUPABASE_URL: Optional[str] = None
    SUPABASE_KEY: Optional[str] = None

    # Redis
    REDIS_HOST: str = "localhost"
    REDIS_PORT: int = 6379

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore",
    )

settings = Settings()
