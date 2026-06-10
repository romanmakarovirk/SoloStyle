"""
Chat router — REST + WebSocket messenger for SoloStyle.

Architecture (sized for ~100 concurrent users):
  * REST endpoints for: list conversations, fetch history, start conversation
  * One WebSocket per connected user at /ws/chat?token=<jwt>
  * In-process subscription registry (dict[external_id, set[WebSocket]])
    — single Render instance, no Redis at this scale
  * Postgres for persistence (Supabase)

WS protocol (JSON over text frames)

  Client → Server:
    {"type":"send","conversation_id":"<uuid>","client_message_id":"<uuid>","content_type":"text","body":"…"}
    {"type":"send","conversation_id":"<uuid>","client_message_id":"<uuid>","content_type":"photo|voice","attachment_url":"<url>","attachment_meta":{…}}
    {"type":"read","conversation_id":"<uuid>","up_to_seq":N}
    {"type":"typing","conversation_id":"<uuid>"}
    {"type":"ping"}

  Server → Client:
    {"type":"ack","client_message_id":"<uuid>","message":{…full message row…}}
    {"type":"message","conversation_id":"<uuid>","message":{…}}
    {"type":"read","conversation_id":"<uuid>","reader_role":"…","up_to_seq":N}
    {"type":"typing","conversation_id":"<uuid>","from_role":"…"}
    {"type":"pong"}
    {"type":"error","code":"…","message":"…"}
"""

import asyncio
import json
import logging
from datetime import datetime, timezone
from typing import Optional
from uuid import UUID

import jwt
from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    Query,
    WebSocket,
    WebSocketDisconnect,
    status,
)
from pydantic import BaseModel, Field
from supabase import Client

from app.config import settings
from app.database import get_supabase
from app.routers.auth import _get_current_user_id, JWT_ALGORITHM

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/chat")


# ── Pydantic schemas ────────────────────────────────────────────────


class StartConversationRequest(BaseModel):
    """Either side opens a conversation by giving the other party's external_id and the role they (the caller) play."""
    other_external_id: str = Field(..., min_length=1, max_length=128)
    as_role: str = Field(..., pattern="^(master|client)$")


class ConversationOut(BaseModel):
    id: str
    master_external_id: str
    client_external_id: str
    master_display_name: Optional[str] = None
    client_display_name: Optional[str] = None
    last_message_preview: Optional[str] = None
    last_message_at: Optional[str] = None
    unread_master: int = 0
    unread_client: int = 0
    created_at: str


class MessageOut(BaseModel):
    id: str
    conversation_id: str
    sender_role: str
    sender_external_id: str
    content_type: str
    body: Optional[str] = None
    attachment_url: Optional[str] = None
    attachment_meta: Optional[dict] = None
    client_message_id: Optional[str] = None
    seq: int
    delivered_at: Optional[str] = None
    read_at: Optional[str] = None
    created_at: str


# ── DB helpers ──────────────────────────────────────────────────────


def _conversation_row_to_out(row: dict, names: dict[str, str] | None = None) -> ConversationOut:
    names = names or {}
    return ConversationOut(
        id=str(row["id"]),
        master_external_id=row["master_external_id"],
        client_external_id=row["client_external_id"],
        master_display_name=names.get(row["master_external_id"]),
        client_display_name=names.get(row["client_external_id"]),
        last_message_preview=row.get("last_message_preview"),
        last_message_at=row.get("last_message_at"),
        unread_master=row.get("unread_master") or 0,
        unread_client=row.get("unread_client") or 0,
        created_at=row["created_at"],
    )


def _resolve_display_names(db: Client, external_ids: set[str]) -> dict[str, str]:
    """
    Map external_id (str(telegram_id) or apple_user_id) → "First Last".

    Both lookups are batched (one query per id-kind), and failures fall back
    to an empty map — the client renders the id prefix in that case, same as
    before this feature existed.
    """
    if not external_ids:
        return {}

    telegram_ids = [int(x) for x in external_ids if x.isdigit()]
    apple_ids = [x for x in external_ids if not x.isdigit()]

    names: dict[str, str] = {}

    def _full_name(row: dict) -> str:
        first = (row.get("first_name") or "").strip()
        last = (row.get("last_name") or "").strip()
        return f"{first} {last}".strip() or first

    try:
        if telegram_ids:
            rows = (
                db.table("users")
                .select("telegram_id,first_name,last_name")
                .in_("telegram_id", telegram_ids)
                .execute()
            ).data or []
            for r in rows:
                if r.get("telegram_id") is not None and _full_name(r):
                    names[str(r["telegram_id"])] = _full_name(r)

        if apple_ids:
            rows = (
                db.table("users")
                .select("apple_user_id,first_name,last_name")
                .in_("apple_user_id", apple_ids)
                .execute()
            ).data or []
            for r in rows:
                if r.get("apple_user_id") and _full_name(r):
                    names[r["apple_user_id"]] = _full_name(r)
    except Exception:
        logger.exception("[CHAT] display-name lookup failed; returning partial map")

    return names


def _message_row_to_out(row: dict) -> MessageOut:
    return MessageOut(
        id=str(row["id"]),
        conversation_id=str(row["conversation_id"]),
        sender_role=row["sender_role"],
        sender_external_id=row["sender_external_id"],
        content_type=row["content_type"],
        body=row.get("body"),
        attachment_url=row.get("attachment_url"),
        attachment_meta=row.get("attachment_meta"),
        client_message_id=str(row["client_message_id"]) if row.get("client_message_id") else None,
        seq=row["seq"],
        delivered_at=row.get("delivered_at"),
        read_at=row.get("read_at"),
        created_at=row["created_at"],
    )


def _find_or_create_conversation(
    db: Client, master_id: str, client_id: str
) -> dict:
    """Look up conversation by (master, client) pair; create if missing."""
    existing = (
        db.table("conversations")
        .select("*")
        .eq("master_external_id", master_id)
        .eq("client_external_id", client_id)
        .execute()
    )
    if existing.data:
        return existing.data[0]

    inserted = (
        db.table("conversations")
        .insert(
            {
                "master_external_id": master_id,
                "client_external_id": client_id,
            }
        )
        .execute()
    )
    return inserted.data[0]


def _user_in_conversation(conv: dict, external_id: str) -> Optional[str]:
    """Return 'master' or 'client' if the user is part of the conversation, else None."""
    if conv["master_external_id"] == external_id:
        return "master"
    if conv["client_external_id"] == external_id:
        return "client"
    return None


# ── REST endpoints ──────────────────────────────────────────────────


@router.post("/conversations", response_model=ConversationOut)
def start_conversation(
    body: StartConversationRequest,
    user_id: str = Depends(_get_current_user_id),
    db: Client = Depends(get_supabase),
):
    """Find existing or create a new conversation between caller and `other_external_id`."""
    if body.other_external_id == user_id:
        raise HTTPException(status_code=400, detail="Cannot start conversation with self")

    if body.as_role == "master":
        conv = _find_or_create_conversation(db, master_id=user_id, client_id=body.other_external_id)
    else:
        conv = _find_or_create_conversation(db, master_id=body.other_external_id, client_id=user_id)

    names = _resolve_display_names(
        db, {conv["master_external_id"], conv["client_external_id"]}
    )
    return _conversation_row_to_out(conv, names)


@router.get("/conversations", response_model=list[ConversationOut])
def list_conversations(
    user_id: str = Depends(_get_current_user_id),
    db: Client = Depends(get_supabase),
):
    """All conversations the caller participates in, newest activity first."""
    master_side = (
        db.table("conversations")
        .select("*")
        .eq("master_external_id", user_id)
        .execute()
    ).data or []
    client_side = (
        db.table("conversations")
        .select("*")
        .eq("client_external_id", user_id)
        .execute()
    ).data or []

    rows = master_side + client_side
    rows.sort(key=lambda r: r.get("last_message_at") or r["created_at"], reverse=True)

    all_ids = {r["master_external_id"] for r in rows} | {r["client_external_id"] for r in rows}
    names = _resolve_display_names(db, all_ids)
    return [_conversation_row_to_out(r, names) for r in rows]


@router.get(
    "/conversations/{conversation_id}/messages",
    response_model=list[MessageOut],
)
def list_messages(
    conversation_id: UUID,
    since_seq: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    user_id: str = Depends(_get_current_user_id),
    db: Client = Depends(get_supabase),
):
    """Fetch history for sync / scroll-back. since_seq=0 returns everything from start."""
    conv_row = (
        db.table("conversations")
        .select("*")
        .eq("id", str(conversation_id))
        .execute()
    ).data
    if not conv_row:
        raise HTTPException(status_code=404, detail="Conversation not found")

    if not _user_in_conversation(conv_row[0], user_id):
        raise HTTPException(status_code=403, detail="Not a participant")

    rows = (
        db.table("chat_messages")
        .select("*")
        .eq("conversation_id", str(conversation_id))
        .gt("seq", since_seq)
        .order("seq")
        .limit(limit)
        .execute()
    ).data or []

    return [_message_row_to_out(r) for r in rows]


# ── WebSocket subscription registry ─────────────────────────────────


class SubscriptionRegistry:
    """In-process map of external_id -> set of active WebSockets.

    Each user can have multiple sockets (e.g. app foregrounded and a debugger
    open at the same time).  When a message arrives we broadcast to all of
    them.  No locking needed — asyncio is cooperative and we never await
    inside add/remove.
    """

    def __init__(self) -> None:
        self._subs: dict[str, set[WebSocket]] = {}

    def add(self, external_id: str, ws: WebSocket) -> None:
        self._subs.setdefault(external_id, set()).add(ws)

    def remove(self, external_id: str, ws: WebSocket) -> None:
        bucket = self._subs.get(external_id)
        if bucket is None:
            return
        bucket.discard(ws)
        if not bucket:
            self._subs.pop(external_id, None)

    def get(self, external_id: str) -> list[WebSocket]:
        return list(self._subs.get(external_id, ()))


_registry = SubscriptionRegistry()


async def _safe_send(ws: WebSocket, payload: dict) -> bool:
    """Send JSON to a socket; if it fails the caller should treat it as disconnected."""
    try:
        await ws.send_text(json.dumps(payload, default=str))
        return True
    except Exception as e:
        logger.warning("[CHAT-WS] send failed: %s", e)
        return False


async def _broadcast(external_id: str, payload: dict) -> None:
    """Fan out a payload to every socket of a user."""
    sockets = _registry.get(external_id)
    if not sockets:
        return
    results = await asyncio.gather(
        *(_safe_send(ws, payload) for ws in sockets),
        return_exceptions=True,
    )
    for ws, ok in zip(sockets, results):
        if ok is not True:
            _registry.remove(external_id, ws)


# ── WebSocket auth ──────────────────────────────────────────────────


def _decode_jwt_safe(token: str) -> Optional[str]:
    """Return the `sub` claim or None if the token is invalid/expired."""
    try:
        payload = jwt.decode(
            token, settings.jwt_secret, algorithms=[JWT_ALGORITHM]
        )
    except jwt.ExpiredSignatureError:
        return None
    except jwt.InvalidTokenError:
        return None
    sub = payload.get("sub")
    return str(sub) if sub else None


# ── WS message handlers ─────────────────────────────────────────────


def _insert_message_idempotent(
    db: Client,
    conv_id: str,
    sender_role: str,
    sender_external_id: str,
    content_type: str,
    body: Optional[str],
    attachment_url: Optional[str],
    attachment_meta: Optional[dict],
    client_message_id: Optional[str],
) -> dict:
    """
    Insert a message; if (conv_id, client_message_id) already exists we
    return the existing row so retries are no-ops.
    """
    if client_message_id:
        existing = (
            db.table("chat_messages")
            .select("*")
            .eq("conversation_id", conv_id)
            .eq("client_message_id", client_message_id)
            .execute()
        )
        if existing.data:
            return existing.data[0]

    inserted = (
        db.table("chat_messages")
        .insert(
            {
                "conversation_id": conv_id,
                "sender_role": sender_role,
                "sender_external_id": sender_external_id,
                "content_type": content_type,
                "body": body,
                "attachment_url": attachment_url,
                "attachment_meta": attachment_meta,
                "client_message_id": client_message_id,
            }
        )
        .execute()
    )
    return inserted.data[0]


def _update_conversation_after_send(
    db: Client, conv: dict, sender_role: str, preview: str
) -> None:
    """Bump last_message_at, store preview, increment receiver's unread counter."""
    update: dict = {
        "last_message_at": datetime.now(timezone.utc).isoformat(),
        "last_message_preview": preview[:140],
    }
    if sender_role == "master":
        update["unread_client"] = (conv.get("unread_client") or 0) + 1
    else:
        update["unread_master"] = (conv.get("unread_master") or 0) + 1
    db.table("conversations").update(update).eq("id", conv["id"]).execute()


def _mark_read(
    db: Client, conv: dict, reader_role: str, up_to_seq: int
) -> None:
    """Stamp messages addressed to the reader as read, zero their unread counter."""
    other_role = "client" if reader_role == "master" else "master"
    now = datetime.now(timezone.utc).isoformat()

    db.table("chat_messages").update({"read_at": now}).match(
        {"conversation_id": conv["id"], "sender_role": other_role}
    ).lte("seq", up_to_seq).is_("read_at", "null").execute()

    counter_field = "unread_master" if reader_role == "master" else "unread_client"
    db.table("conversations").update({counter_field: 0}).eq("id", conv["id"]).execute()


async def _handle_send(
    db: Client,
    user_id: str,
    payload: dict,
    ws: WebSocket,
) -> None:
    """Handle a 'send' frame from the client."""
    conv_id = payload.get("conversation_id")
    client_msg_id = payload.get("client_message_id")
    content_type = payload.get("content_type", "text")
    body = payload.get("body")
    attachment_url = payload.get("attachment_url")
    attachment_meta = payload.get("attachment_meta")

    if not conv_id:
        await _safe_send(ws, {"type": "error", "code": "missing_conv_id", "message": "conversation_id required"})
        return
    if content_type not in ("text", "photo", "voice"):
        await _safe_send(ws, {"type": "error", "code": "bad_content_type", "message": f"unsupported content_type: {content_type}"})
        return
    if content_type == "text" and not (body or "").strip():
        await _safe_send(ws, {"type": "error", "code": "empty_body", "message": "text message body required"})
        return

    # Look up conversation, verify membership, determine sender role
    conv_row = (
        db.table("conversations").select("*").eq("id", conv_id).execute()
    ).data
    if not conv_row:
        await _safe_send(ws, {"type": "error", "code": "conv_not_found", "message": "conversation not found"})
        return
    conv = conv_row[0]
    sender_role = _user_in_conversation(conv, user_id)
    if sender_role is None:
        await _safe_send(ws, {"type": "error", "code": "forbidden", "message": "not a participant"})
        return

    # Insert (idempotent) + update conversation in two steps; if the network
    # retries the same client_message_id we'll re-broadcast the same row,
    # which is correct.
    msg = _insert_message_idempotent(
        db,
        conv_id=conv_id,
        sender_role=sender_role,
        sender_external_id=user_id,
        content_type=content_type,
        body=body,
        attachment_url=attachment_url,
        attachment_meta=attachment_meta,
        client_message_id=client_msg_id,
    )

    preview = body if content_type == "text" else (
        "📷 Фото" if content_type == "photo" else "🎙 Голосовое"
    )
    _update_conversation_after_send(db, conv, sender_role, preview or "")

    msg_out = _message_row_to_out(msg).model_dump()

    # ACK to sender (so its outbox can mark sent + reconcile its temp ID)
    await _safe_send(ws, {"type": "ack", "client_message_id": client_msg_id, "message": msg_out})

    # Broadcast to *both* sides — sender may have multiple devices
    other_external_id = (
        conv["client_external_id"] if sender_role == "master" else conv["master_external_id"]
    )
    fan_payload = {"type": "message", "conversation_id": conv_id, "message": msg_out}
    await asyncio.gather(
        _broadcast(other_external_id, fan_payload),
        # also echo to the sender's other devices (skip the socket we already ACKed)
        _broadcast_skip(user_id, fan_payload, skip=ws),
    )


async def _broadcast_skip(external_id: str, payload: dict, skip: WebSocket) -> None:
    """Broadcast to all sockets of a user EXCEPT the given one."""
    sockets = [s for s in _registry.get(external_id) if s is not skip]
    if not sockets:
        return
    await asyncio.gather(*(_safe_send(ws, payload) for ws in sockets), return_exceptions=True)


async def _handle_read(db: Client, user_id: str, payload: dict, ws: WebSocket) -> None:
    conv_id = payload.get("conversation_id")
    up_to_seq = int(payload.get("up_to_seq") or 0)
    if not conv_id or up_to_seq <= 0:
        await _safe_send(ws, {"type": "error", "code": "bad_read", "message": "conversation_id and up_to_seq required"})
        return

    conv_row = (db.table("conversations").select("*").eq("id", conv_id).execute()).data
    if not conv_row:
        return
    conv = conv_row[0]
    reader_role = _user_in_conversation(conv, user_id)
    if reader_role is None:
        return

    _mark_read(db, conv, reader_role, up_to_seq)

    other_external_id = (
        conv["client_external_id"] if reader_role == "master" else conv["master_external_id"]
    )
    await _broadcast(
        other_external_id,
        {"type": "read", "conversation_id": conv_id, "reader_role": reader_role, "up_to_seq": up_to_seq},
    )


async def _handle_typing(db: Client, user_id: str, payload: dict) -> None:
    conv_id = payload.get("conversation_id")
    if not conv_id:
        return
    conv_row = (db.table("conversations").select("*").eq("id", conv_id).execute()).data
    if not conv_row:
        return
    conv = conv_row[0]
    sender_role = _user_in_conversation(conv, user_id)
    if sender_role is None:
        return
    other_external_id = (
        conv["client_external_id"] if sender_role == "master" else conv["master_external_id"]
    )
    await _broadcast(
        other_external_id,
        {"type": "typing", "conversation_id": conv_id, "from_role": sender_role},
    )


# ── WebSocket endpoint ──────────────────────────────────────────────


@router.websocket("/ws")
async def chat_websocket(
    websocket: WebSocket,
    token: str = Query(..., description="JWT access token"),
):
    """Authenticated chat WebSocket. Single connection per device, multiple devices supported."""
    user_id = _decode_jwt_safe(token)
    if not user_id:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION, reason="invalid token")
        return

    await websocket.accept()
    _registry.add(user_id, websocket)
    db = get_supabase()
    logger.info("[CHAT-WS] connect user=%s", user_id)

    try:
        while True:
            raw = await websocket.receive_text()
            try:
                payload = json.loads(raw)
            except json.JSONDecodeError:
                await _safe_send(websocket, {"type": "error", "code": "bad_json", "message": "expected JSON"})
                continue

            kind = payload.get("type")
            try:
                if kind == "ping":
                    await _safe_send(websocket, {"type": "pong"})
                elif kind == "send":
                    await _handle_send(db, user_id, payload, websocket)
                elif kind == "read":
                    await _handle_read(db, user_id, payload, websocket)
                elif kind == "typing":
                    await _handle_typing(db, user_id, payload)
                else:
                    await _safe_send(websocket, {"type": "error", "code": "unknown_type", "message": f"unknown type: {kind}"})
            except Exception as e:
                logger.exception("[CHAT-WS] handler error")
                await _safe_send(websocket, {"type": "error", "code": "internal", "message": str(e)})

    except WebSocketDisconnect:
        logger.info("[CHAT-WS] disconnect user=%s", user_id)
    except Exception:
        logger.exception("[CHAT-WS] unexpected error, dropping socket")
    finally:
        _registry.remove(user_id, websocket)
