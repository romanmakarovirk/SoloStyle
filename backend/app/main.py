import asyncio
import os

import httpx
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routers import auth, health, masters, search, services, voice_crm

app = FastAPI(title="SoloStyle API", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health.router, tags=["Health"])
app.include_router(masters.router, prefix="/api/v1", tags=["Masters"])
app.include_router(services.router, prefix="/api/v1", tags=["Services"])
app.include_router(search.router, prefix="/api/v1", tags=["Search"])
app.include_router(voice_crm.router, prefix="/api/v1", tags=["Voice CRM"])
app.include_router(auth.router, prefix="/api/v1", tags=["Auth"])


@app.get("/")
def root():
    return {"app": "SoloStyle API", "version": "0.1.0"}


# --------------- Keep-alive self-ping ---------------
# Railway/Render free plans sleep after ~15 min of inactivity.
# This background task pings /health every 10 minutes to prevent sleep.

KEEP_ALIVE_INTERVAL = 10 * 60  # 10 minutes


async def _keep_alive_loop():
    """Ping own /health endpoint to prevent free-tier sleep."""
    # RAILWAY_PUBLIC_DOMAIN or RENDER_EXTERNAL_HOSTNAME set by the platform
    domain = os.getenv("RAILWAY_PUBLIC_DOMAIN") or os.getenv("RENDER_EXTERNAL_HOSTNAME")
    if not domain:
        print("[KEEP-ALIVE] No public domain found, skipping (local dev mode)")
        return

    url = f"https://{domain}/health"
    print(f"[KEEP-ALIVE] Starting self-ping every {KEEP_ALIVE_INTERVAL}s → {url}")

    await asyncio.sleep(30)  # wait for server to fully start

    async with httpx.AsyncClient(timeout=10.0) as client:
        while True:
            try:
                resp = await client.get(url)
                print(f"[KEEP-ALIVE] ping → {resp.status_code}")
            except Exception as e:
                print(f"[KEEP-ALIVE] ping error: {e}")
            await asyncio.sleep(KEEP_ALIVE_INTERVAL)


@app.on_event("startup")
async def start_keep_alive():
    asyncio.create_task(_keep_alive_loop())


# --------------- Telegram Bot (inline polling) ---------------

async def _run_telegram_bot():
    """Run Telegram bot polling inside the same process as FastAPI."""
    from app.config import settings

    token = settings.telegram_bot_token
    if not token:
        print("[TG-BOT] TELEGRAM_BOT_TOKEN not set, skipping")
        return

    from telegram import Update
    from telegram.ext import Application, CommandHandler, ContextTypes

    api_base = os.getenv("API_BASE_URL", "https://solostyle-api.onrender.com/api/v1")

    async def start_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
        user = update.effective_user
        if not user:
            return

        auth_token = context.args[0] if context.args else None

        if not auth_token:
            await update.message.reply_text(
                f"Привет, {user.first_name}! 👋\n\n"
                "Я бот SoloStyle. Чтобы войти в приложение, "
                "откройте его и нажмите «Войти через Telegram»."
            )
            return

        print(f"[TG-BOT] Auth from {user.id} ({user.first_name}), token {auth_token[:8]}...")

        photo_url = None
        try:
            photos = await user.get_profile_photos(limit=1)
            if photos.total_count > 0:
                file = await context.bot.get_file(photos.photos[0][-1].file_id)
                photo_url = file.file_path
        except Exception as e:
            print(f"[TG-BOT] Photo error: {e}")

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
                resp = await client.post(f"{api_base}/auth/telegram-webhook", json=payload)

            if resp.status_code == 200:
                await update.message.reply_text(
                    f"Готово, {user.first_name}! ✅\n\n"
                    "Вернитесь в приложение SoloStyle — вход выполнен автоматически."
                )
            elif resp.status_code == 410:
                await update.message.reply_text("Время входа истекло ⏱\nОткройте приложение и попробуйте снова.")
            else:
                print(f"[TG-BOT] Backend error: {resp.status_code} {resp.text}")
                await update.message.reply_text("Произошла ошибка. Попробуйте позже.")
        except Exception as e:
            print(f"[TG-BOT] Request error: {e}")
            await update.message.reply_text("Не удалось связаться с сервером. Попробуйте позже.")

    bot_app = Application.builder().token(token).build()
    bot_app.add_handler(CommandHandler("start", start_handler))

    await bot_app.initialize()
    await bot_app.start()
    await bot_app.updater.start_polling(allowed_updates=Update.ALL_TYPES)
    print("[TG-BOT] Bot started polling")


@app.on_event("startup")
async def start_telegram_bot():
    asyncio.create_task(_run_telegram_bot())
