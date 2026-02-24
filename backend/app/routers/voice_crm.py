import json
import re
from datetime import datetime

import httpx
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from app.config import settings

router = APIRouter()

# ── Models ──────────────────────────────────────────

class VoiceCRMRequest(BaseModel):
    text: str
    timezone: str = "Asia/Irkutsk"


class ParsedEntity(BaseModel):
    client_name: str | None = None
    phone: str | None = None
    service_name: str | None = None
    date: str | None = None       # ISO-8601 string
    time: str | None = None       # "HH:MM"
    price: float | None = None
    notes: str | None = None


class VoiceCRMResponse(BaseModel):
    success: bool
    entities: ParsedEntity
    summary: str                   # Human-readable confirmation text


# ── System prompt ───────────────────────────────────

VOICE_CRM_PROMPT = """\
Ты — AI-ассистент CRM-системы для индивидуального мастера красоты (парикмахер, маникюр, массаж и т.д.).
Пользователь продиктовал голосовое сообщение. Твоя задача — извлечь структурированные данные.

Текущая дата и время: {now}
Часовой пояс: {tz}

Извлеки из текста следующие поля (если упомянуты):
- client_name: имя клиента
- phone: телефон клиента (формат +7XXXXXXXXXX)
- service_name: название услуги
- date: дата записи (ISO-8601, например "2026-02-25")
- time: время записи ("HH:MM", 24-часовой формат)
- price: цена услуги (число)
- notes: дополнительные заметки

Правила:
1. "завтра" = следующий день от текущей даты
2. "послезавтра" = +2 дня
3. "в понедельник" / "во вторник" и т.д. = ближайший такой день недели
4. Если время указано как "в три", "в 3" — это 15:00 (дневное время для салона)
5. Если данных нет — оставь поле null
6. НЕ выдумывай данные, которых нет в тексте

Ответь ТОЛЬКО валидным JSON объектом без markdown-обёрток:
{{"client_name": ..., "phone": ..., "service_name": ..., "date": ..., "time": ..., "price": ..., "notes": ...}}
"""


# ── Endpoint ────────────────────────────────────────

@router.post("/voice-crm", response_model=VoiceCRMResponse)
async def parse_voice_crm(req: VoiceCRMRequest):
    text = req.text.strip()
    if not text:
        raise HTTPException(status_code=400, detail="Empty text")

    now_str = datetime.now().strftime("%Y-%m-%d %H:%M")
    system = VOICE_CRM_PROMPT.format(now=now_str, tz=req.timezone)

    raw_json = await _call_groq(text, system)
    entities = _parse_entities(raw_json)
    summary = _build_summary(entities)

    return VoiceCRMResponse(
        success=True,
        entities=entities,
        summary=summary,
    )


# ── Groq helper ────────────────────────────────────

async def _call_groq(user_message: str, system_prompt: str) -> str:
    if not settings.groq_api_key:
        raise HTTPException(status_code=500, detail="GROQ_API_KEY not configured")

    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.post(
            "https://api.groq.com/openai/v1/chat/completions",
            headers={
                "Authorization": f"Bearer {settings.groq_api_key}",
                "Content-Type": "application/json",
            },
            json={
                "model": "llama-3.1-8b-instant",
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_message},
                ],
                "temperature": 0.1,
                "max_tokens": 300,
            },
        )

    if response.status_code != 200:
        raise HTTPException(
            status_code=502,
            detail=f"Groq API error: {response.status_code} — {response.text}",
        )

    data = response.json()
    return data["choices"][0]["message"]["content"]


# ── Parse helpers ──────────────────────────────────

def _parse_entities(raw: str) -> ParsedEntity:
    """Parse JSON from LLM response, handling possible markdown wrapping."""
    # Strip markdown code fences if present
    cleaned = raw.strip()
    if cleaned.startswith("```"):
        cleaned = re.sub(r"^```(?:json)?\s*", "", cleaned)
        cleaned = re.sub(r"\s*```$", "", cleaned)

    try:
        obj = json.loads(cleaned)
    except json.JSONDecodeError:
        # Try to find JSON object in the text
        match = re.search(r"\{.*\}", cleaned, re.DOTALL)
        if match:
            obj = json.loads(match.group())
        else:
            return ParsedEntity()

    return ParsedEntity(
        client_name=obj.get("client_name"),
        phone=obj.get("phone"),
        service_name=obj.get("service_name"),
        date=obj.get("date"),
        time=obj.get("time"),
        price=float(obj["price"]) if obj.get("price") is not None else None,
        notes=obj.get("notes"),
    )


def _build_summary(e: ParsedEntity) -> str:
    """Build human-readable confirmation string in Russian."""
    parts: list[str] = []

    if e.client_name:
        parts.append(f"Клиент: {e.client_name}")
    if e.service_name:
        parts.append(f"Услуга: {e.service_name}")
    if e.date:
        try:
            d = datetime.fromisoformat(e.date)
            parts.append(f"Дата: {d.strftime('%d.%m.%Y')}")
        except ValueError:
            parts.append(f"Дата: {e.date}")
    if e.time:
        parts.append(f"Время: {e.time}")
    if e.price is not None:
        parts.append(f"Цена: {int(e.price)} ₽")
    if e.phone:
        parts.append(f"Телефон: {e.phone}")
    if e.notes:
        parts.append(f"Заметка: {e.notes}")

    if not parts:
        return "Не удалось распознать данные из сообщения. Попробуйте ещё раз."

    return "\n".join(parts)
