from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    supabase_url: str
    supabase_key: str
    groq_api_key: str = ""
    telegram_bot_token: str = ""
    jwt_secret: str = "change-me-in-production"

    class Config:
        env_file = ".env"


settings = Settings()
