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
