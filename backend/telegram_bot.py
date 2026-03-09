"""
SoloStyle Telegram Bot — handles /start <auth_token> for login flow.

Deployment: Run alongside the FastAPI server, or deploy separately.

Usage:
    TELEGRAM_BOT_TOKEN=... API_BASE_URL=https://solostyle-api.onrender.com/api/v1 python telegram_bot.py

Flow:
1. User opens tg://resolve?domain=solostyle_bot&start=AUTH_TOKEN
2. Bot receives /start AUTH_TOKEN
3. Bot calls POST /api/v1/auth/telegram-webhook with user data + auth_token
4. iOS app polls /auth/check-token and gets JWT
"""

import os
import logging

import httpx
from telegram import Update
from telegram.ext import Application, CommandHandler, ContextTypes

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN", "")
API_BASE_URL = os.getenv("API_BASE_URL", "https://solostyle-api.onrender.com/api/v1")


async def start_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /start command with optional auth_token deep link parameter."""
    user = update.effective_user
    if not user:
        return

    # Check for deep link parameter (auth_token)
    auth_token = context.args[0] if context.args else None

    if not auth_token:
        # Regular /start without deep link — just greet
        await update.message.reply_text(
            f"Привет, {user.first_name}! 👋\n\n"
            "Я бот SoloStyle. Чтобы войти в приложение, "
            "откройте его и нажмите «Войти через Telegram»."
        )
        return

    # Deep link auth flow — send user data to backend
    logger.info(f"Auth request from {user.id} ({user.first_name}) with token {auth_token[:8]}...")

    # Get user profile photo URL
    photo_url = None
    try:
        photos = await user.get_profile_photos(limit=1)
        if photos.total_count > 0:
            photo = photos.photos[0][-1]  # Largest size
            file = await context.bot.get_file(photo.file_id)
            photo_url = file.file_path
    except Exception as e:
        logger.warning(f"Could not get profile photo: {e}")

    # Call backend webhook
    payload = {
        "auth_token": auth_token,
        "telegram_id": user.id,
        "first_name": user.first_name,
        "last_name": user.last_name,
        "username": user.username,
        "photo_url": photo_url,
    }

    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.post(f"{API_BASE_URL}/auth/telegram-webhook", json=payload)

        if resp.status_code == 200:
            await update.message.reply_text(
                f"Готово, {user.first_name}! ✅\n\n"
                "Вернитесь в приложение SoloStyle — вход выполнен автоматически."
            )
        elif resp.status_code == 410:
            await update.message.reply_text(
                "Время входа истекло ⏱\n\n"
                "Откройте приложение и попробуйте снова."
            )
        elif resp.status_code == 404:
            await update.message.reply_text(
                "Токен не найден 🤔\n\n"
                "Откройте приложение и нажмите «Войти через Telegram» ещё раз."
            )
        else:
            logger.error(f"Backend error: {resp.status_code} {resp.text}")
            await update.message.reply_text(
                "Произошла ошибка. Попробуйте позже."
            )
    except Exception as e:
        logger.error(f"Failed to call backend: {e}")
        await update.message.reply_text(
            "Не удалось связаться с сервером. Попробуйте позже."
        )


def main():
    if not BOT_TOKEN:
        logger.error("TELEGRAM_BOT_TOKEN not set!")
        return

    app = Application.builder().token(BOT_TOKEN).build()
    app.add_handler(CommandHandler("start", start_handler))

    logger.info("SoloStyle bot started")
    app.run_polling(allowed_updates=Update.ALL_TYPES)


if __name__ == "__main__":
    main()
