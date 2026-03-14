"""
Auth router — Telegram + Apple login flow with JWT tokens.

Telegram flow:
1. iOS app generates UUID auth_token → POST /auth/register-token
2. iOS opens tg://resolve?domain=solostyle_registration_bot&start=AUTH_TOKEN
3. User taps /start in Telegram bot → bot sends webhook to POST /auth/telegram-webhook
4. Backend creates JWT, stores it in auth_tokens row
5. iOS polls GET /auth/check-token?auth_token=UUID → gets JWT when ready
6. iOS validates JWT → POST /auth/validate → gets user info
7. iOS sets role → PUT /auth/role

Apple flow:
1. iOS shows SignInWithAppleButton → gets identityToken
2. iOS sends token to POST /auth/apple
3. Backend verifies with Apple JWKS, creates user + JWT
4. iOS validates JWT → POST /auth/validate → gets user info
"""

import logging
from datetime import datetime, timedelta, timezone

import httpx
import jwt
from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel
from supabase import Client

from app.config import settings
from app.database import get_supabase

logger = logging.getLogger(__name__)

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


class AppleAuthRequest(BaseModel):
    """Payload from iOS Sign in with Apple."""
    identity_token: str  # JWT from Apple
    user_id: str  # Apple user identifier
    first_name: str | None = None
    last_name: str | None = None
    email: str | None = None


# ── Helpers ─────────────────────────────────────────────────────────

def _db_select_one(db: Client, table: str, column: str, value) -> dict | None:
    """Safe select that returns first row or None. No maybe_single()."""
    result = db.table(table).select("*").eq(column, value).execute()
    if result.data and len(result.data) > 0:
        return result.data[0]
    return None


def _create_jwt(user_id: str, provider: str = "telegram") -> str:
    payload = {
        "sub": user_id,
        "provider": provider,
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


def _get_current_user_id(authorization: str = Header(...)) -> str:
    """Extract user ID from Authorization: Bearer <jwt> header."""
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing Bearer token")
    token = authorization[7:]
    payload = _decode_jwt(token)
    return payload["sub"]


# ── Telegram Endpoints ──────────────────────────────────────────────

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
    row = _db_select_one(db, "auth_tokens", "auth_token", auth_token)

    if not row:
        raise HTTPException(status_code=404, detail="Token not found")

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
        token_row = _db_select_one(db, "auth_tokens", "auth_token", body.auth_token)

        if not token_row:
            print(f"[AUTH] telegram-webhook: token NOT FOUND in DB")
            raise HTTPException(status_code=404, detail="Auth token not found")

        print(f"[AUTH] telegram-webhook: token found, expires_at={token_row.get('expires_at')}")

        # Check expiry
        expires_str = token_row.get("expires_at")
        if expires_str:
            expires_at = datetime.fromisoformat(str(expires_str))
            if datetime.now(timezone.utc) > expires_at:
                raise HTTPException(status_code=410, detail="Auth token expired")

        # Upsert user in users table
        print(f"[AUTH] telegram-webhook: upserting user {body.telegram_id}...")
        now = datetime.now(timezone.utc).isoformat()
        user_data = {
            "telegram_id": body.telegram_id,
            "first_name": body.first_name,
            "last_name": body.last_name,
            "username": body.username,
            "photo_url": body.photo_url,
            "auth_provider": "telegram",
            "updated_at": now,
        }

        existing = _db_select_one(db, "users", "telegram_id", body.telegram_id)
        if existing:
            print(f"[AUTH] telegram-webhook: updating existing user")
            db.table("users").update(user_data).eq("telegram_id", body.telegram_id).execute()
        else:
            print(f"[AUTH] telegram-webhook: inserting new user")
            user_data["created_at"] = now
            db.table("users").insert(user_data).execute()

        # Generate JWT
        print(f"[AUTH] telegram-webhook: generating JWT...")
        token = _create_jwt(str(body.telegram_id), provider="telegram")

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


# ── Apple Sign-In Endpoint ──────────────────────────────────────────

# Cache Apple public keys
_apple_keys_cache: dict | None = None


def _get_apple_public_keys() -> dict:
    """Fetch Apple's public keys for JWT verification."""
    global _apple_keys_cache
    if _apple_keys_cache:
        return _apple_keys_cache

    resp = httpx.get("https://appleid.apple.com/auth/keys", timeout=10.0)
    resp.raise_for_status()
    _apple_keys_cache = resp.json()
    return _apple_keys_cache


def _verify_apple_token(identity_token: str) -> dict:
    """Verify Apple identity token and return claims."""
    from jwt import PyJWKClient

    try:
        jwks_client = PyJWKClient("https://appleid.apple.com/auth/keys")
        signing_key = jwks_client.get_signing_key_from_jwt(identity_token)

        claims = jwt.decode(
            identity_token,
            signing_key.key,
            algorithms=["RS256"],
            audience=settings.apple_bundle_id if hasattr(settings, 'apple_bundle_id') else "com.solostyle.SoloStyle",
            issuer="https://appleid.apple.com",
        )
        return claims
    except Exception as e:
        print(f"[AUTH] Apple token verification failed: {e}")
        raise HTTPException(status_code=401, detail=f"Invalid Apple token: {e}")


@router.post("/apple")
def apple_auth(body: AppleAuthRequest, db: Client = Depends(get_supabase)):
    """Authenticate via Sign in with Apple."""
    print(f"[AUTH] apple: user_id={body.user_id[:8]}...")

    try:
        # Verify Apple identity token
        claims = _verify_apple_token(body.identity_token)
        apple_user_id = claims["sub"]

        print(f"[AUTH] apple: verified, sub={apple_user_id[:8]}...")

        # Upsert user
        now = datetime.now(timezone.utc).isoformat()
        first_name = body.first_name or "User"

        existing = _db_select_one(db, "users", "apple_user_id", apple_user_id)
        if existing:
            print(f"[AUTH] apple: updating existing user")
            update_data = {"updated_at": now, "auth_provider": "apple"}
            if body.first_name:
                update_data["first_name"] = body.first_name
            if body.last_name:
                update_data["last_name"] = body.last_name
            if body.email:
                update_data["email"] = body.email
            db.table("users").update(update_data).eq("apple_user_id", apple_user_id).execute()
        else:
            print(f"[AUTH] apple: inserting new user")
            db.table("users").insert({
                "apple_user_id": apple_user_id,
                "first_name": first_name,
                "last_name": body.last_name,
                "email": body.email,
                "auth_provider": "apple",
                "created_at": now,
                "updated_at": now,
            }).execute()

        # Generate JWT
        token = _create_jwt(apple_user_id, provider="apple")

        print(f"[AUTH] apple: SUCCESS")
        return {"ok": True, "jwt": token}

    except HTTPException:
        raise
    except Exception as e:
        import traceback
        print(f"[AUTH] apple CRASH: {e}")
        print(f"[AUTH] traceback: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=f"Internal error: {e}")


# ── Common Endpoints ────────────────────────────────────────────────

@router.post("/validate", response_model=ValidateResponse)
def validate_token(
    user_id: str = Depends(_get_current_user_id),
    db: Client = Depends(get_supabase),
):
    """Step 6: iOS validates JWT and gets user info."""
    # Try telegram_id first, then apple_user_id
    user = _db_select_one(db, "users", "telegram_id", int(user_id)) if user_id.isdigit() else None
    if not user:
        user = _db_select_one(db, "users", "apple_user_id", user_id)

    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    return ValidateResponse(
        user={
            "telegram_id": user.get("telegram_id"),
            "first_name": user["first_name"],
            "last_name": user.get("last_name"),
            "username": user.get("username"),
            "photo_url": user.get("photo_url"),
            "email": user.get("email"),
            "apple_user_id": user.get("apple_user_id"),
        },
        role=user.get("role"),
    )


@router.put("/role")
def update_role(
    body: RoleUpdateRequest,
    user_id: str = Depends(_get_current_user_id),
    db: Client = Depends(get_supabase),
):
    """Step 7: iOS sets user role (master/client)."""
    if body.role not in ("master", "client"):
        raise HTTPException(status_code=400, detail="Role must be 'master' or 'client'")

    now = datetime.now(timezone.utc).isoformat()

    # Update by telegram_id or apple_user_id
    if user_id.isdigit():
        db.table("users").update({"role": body.role, "updated_at": now}).eq("telegram_id", int(user_id)).execute()
    else:
        db.table("users").update({"role": body.role, "updated_at": now}).eq("apple_user_id", user_id).execute()

    return {"ok": True, "role": body.role}
