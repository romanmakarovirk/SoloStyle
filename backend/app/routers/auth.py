"""
Auth router — Telegram login flow with JWT tokens.

Flow:
1. iOS app generates UUID auth_token → POST /auth/register-token
2. iOS opens tg://resolve?domain=solostyle_bot&start=AUTH_TOKEN
3. User taps /start in Telegram bot → bot sends webhook to POST /auth/telegram-webhook
4. Backend creates JWT, stores it in auth_tokens row
5. iOS polls GET /auth/check-token?auth_token=UUID → gets JWT when ready
6. iOS validates JWT → POST /auth/validate → gets user info
7. iOS sets role → PUT /auth/role
"""

from datetime import datetime, timedelta, timezone

import jwt
from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel
from supabase import Client

from app.config import settings
from app.database import get_supabase

router = APIRouter(prefix="/auth")

JWT_ALGORITHM = "HS256"
JWT_EXPIRY_DAYS = 90
AUTH_TOKEN_TTL_MINUTES = 10


# ── Request / Response models ──────────────────────────────────────

class RegisterTokenRequest(BaseModel):
    auth_token: str


class RegisterTokenResponse(BaseModel):
    ok: bool = True


class CheckTokenResponse(BaseModel):
    completed: bool
    jwt: str | None = None


class ValidateResponse(BaseModel):
    user: dict
    role: str | None = None


class RoleUpdateRequest(BaseModel):
    role: str  # "master" | "client"


class TelegramWebhookPayload(BaseModel):
    """Payload sent by the Telegram bot script when a user taps /start."""
    auth_token: str
    telegram_id: int
    first_name: str
    last_name: str | None = None
    username: str | None = None
    photo_url: str | None = None


# ── Helpers ─────────────────────────────────────────────────────────

def _create_jwt(telegram_id: int) -> str:
    payload = {
        "sub": str(telegram_id),
        "iat": datetime.now(timezone.utc),
        "exp": datetime.now(timezone.utc) + timedelta(days=JWT_EXPIRY_DAYS),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=JWT_ALGORITHM)


def _decode_jwt(token: str) -> dict:
    try:
        return jwt.decode(token, settings.jwt_secret, algorithms=[JWT_ALGORITHM])
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")


def _get_current_user_id(authorization: str = Header(...)) -> int:
    """Extract telegram_id from Authorization: Bearer <jwt> header."""
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing Bearer token")
    token = authorization[7:]
    payload = _decode_jwt(token)
    return int(payload["sub"])


# ── Endpoints ───────────────────────────────────────────────────────

@router.post("/register-token", response_model=RegisterTokenResponse)
def register_token(body: RegisterTokenRequest, db: Client = Depends(get_supabase)):
    """Step 1: iOS registers a temporary auth token before opening Telegram."""
    expires_at = (
        datetime.now(timezone.utc) + timedelta(minutes=AUTH_TOKEN_TTL_MINUTES)
    ).isoformat()

    try:
        db.table("auth_tokens").upsert({
            "auth_token": body.auth_token,
            "completed": False,
            "jwt": None,
            "expires_at": expires_at,
        }).execute()
        print(f"[AUTH] register-token OK: {body.auth_token[:8]}...")
    except Exception as e:
        print(f"[AUTH] register-token ERROR: {e}")
        raise HTTPException(status_code=500, detail=f"DB error: {e}")

    return RegisterTokenResponse()


@router.get("/check-token", response_model=CheckTokenResponse)
def check_token(auth_token: str, db: Client = Depends(get_supabase)):
    """Step 5: iOS polls this endpoint to check if Telegram auth completed."""
    result = (
        db.table("auth_tokens")
        .select("completed, jwt")
        .eq("auth_token", auth_token)
        .maybe_single()
        .execute()
    )

    if not result.data:
        raise HTTPException(status_code=404, detail="Token not found")

    row = result.data
    return CheckTokenResponse(completed=row["completed"], jwt=row.get("jwt"))


@router.post("/telegram-webhook")
def telegram_webhook(body: TelegramWebhookPayload, db: Client = Depends(get_supabase)):
    """
    Step 3: Called by the Telegram bot when user sends /start <auth_token>.
    Creates or updates user, generates JWT, marks auth_token as completed.
    """
    print(f"[AUTH] telegram-webhook: user={body.telegram_id}, token={body.auth_token[:8]}...")

    try:
        # Verify the auth_token exists and is not expired
        token_result = (
            db.table("auth_tokens")
            .select("*")
            .eq("auth_token", body.auth_token)
            .maybe_single()
            .execute()
        )

        if not token_result.data:
            print(f"[AUTH] telegram-webhook: token NOT FOUND in DB")
            raise HTTPException(status_code=404, detail="Auth token not found")

        print(f"[AUTH] telegram-webhook: token found, expires_at={token_result.data.get('expires_at')}")

        # Check expiry
        expires_str = token_result.data["expires_at"]
        # Handle Supabase TIMESTAMPTZ format
        if expires_str:
            expires_at = datetime.fromisoformat(expires_str.replace("+00:00", "+00:00"))
            if datetime.now(timezone.utc) > expires_at:
                raise HTTPException(status_code=410, detail="Auth token expired")

        # Upsert user in users table
        print(f"[AUTH] telegram-webhook: upserting user {body.telegram_id}...")
        user_data = {
            "telegram_id": body.telegram_id,
            "first_name": body.first_name,
            "last_name": body.last_name,
            "username": body.username,
            "photo_url": body.photo_url,
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }

        existing = (
            db.table("users")
            .select("*")
            .eq("telegram_id", body.telegram_id)
            .maybe_single()
            .execute()
        )

        if existing.data:
            print(f"[AUTH] telegram-webhook: updating existing user")
            db.table("users").update(user_data).eq("telegram_id", body.telegram_id).execute()
        else:
            print(f"[AUTH] telegram-webhook: inserting new user")
            user_data["created_at"] = datetime.now(timezone.utc).isoformat()
            db.table("users").insert(user_data).execute()

        # Generate JWT
        print(f"[AUTH] telegram-webhook: generating JWT...")
        token = _create_jwt(body.telegram_id)

        # Mark auth_token as completed
        print(f"[AUTH] telegram-webhook: marking token as completed...")
        db.table("auth_tokens").update({
            "completed": True,
            "jwt": token,
        }).eq("auth_token", body.auth_token).execute()

        print(f"[AUTH] telegram-webhook: SUCCESS")
        return {"ok": True}

    except HTTPException:
        raise
    except Exception as e:
        import traceback
        print(f"[AUTH] telegram-webhook CRASH: {e}")
        print(f"[AUTH] traceback: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=f"Internal error: {e}")


@router.post("/validate", response_model=ValidateResponse)
def validate_token(
    telegram_id: int = Depends(_get_current_user_id),
    db: Client = Depends(get_supabase),
):
    """Step 6: iOS validates JWT and gets user info."""
    result = (
        db.table("users")
        .select("*")
        .eq("telegram_id", telegram_id)
        .maybe_single()
        .execute()
    )

    if not result.data:
        raise HTTPException(status_code=404, detail="User not found")

    user = result.data
    return ValidateResponse(
        user={
            "telegram_id": user["telegram_id"],
            "first_name": user["first_name"],
            "last_name": user.get("last_name"),
            "username": user.get("username"),
            "photo_url": user.get("photo_url"),
        },
        role=user.get("role"),
    )


@router.put("/role")
def update_role(
    body: RoleUpdateRequest,
    telegram_id: int = Depends(_get_current_user_id),
    db: Client = Depends(get_supabase),
):
    """Step 7: iOS sets user role (master/client)."""
    if body.role not in ("master", "client"):
        raise HTTPException(status_code=400, detail="Role must be 'master' or 'client'")

    db.table("users").update({
        "role": body.role,
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }).eq("telegram_id", telegram_id).execute()

    return {"ok": True, "role": body.role}
