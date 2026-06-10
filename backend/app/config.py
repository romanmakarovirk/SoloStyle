import logging
import secrets

from pydantic_settings import BaseSettings

logger = logging.getLogger(__name__)

_INSECURE_DEFAULT = "change-me-in-production"


class Settings(BaseSettings):
    supabase_url: str
    supabase_key: str
    groq_api_key: str = ""
    telegram_bot_token: str = ""
    jwt_secret: str = _INSECURE_DEFAULT
    # Dedicated secret for internal webhook calls (Telegram bot → API).
    # Falls back to jwt_secret only if unset, but keeping them separate means
    # a leaked webhook secret can't be used to forge user JWTs.
    webhook_secret: str = ""

    class Config:
        env_file = ".env"

    @property
    def effective_webhook_secret(self) -> str:
        return self.webhook_secret or self.jwt_secret


settings = Settings()

# Fail loudly if the signing key was never configured. If the process is
# running with the public default, every JWT is forgeable — refuse to keep
# that quiet. A per-process random key is generated so the server still runs
# (e.g. local dev) but every restart invalidates tokens, making the
# misconfiguration impossible to ignore.
if settings.jwt_secret == _INSECURE_DEFAULT:
    logger.error(
        "[CONFIG] JWT_SECRET is unset — using a random per-process key. "
        "Set JWT_SECRET in the environment for any real deployment."
    )
    settings.jwt_secret = secrets.token_urlsafe(48)
