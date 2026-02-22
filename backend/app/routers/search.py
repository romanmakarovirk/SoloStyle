import httpx
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from supabase import Client

from app.config import settings
from app.database import get_supabase
from app.embeddings import embed_text

router = APIRouter()

# Mapping English service names → Russian
SERVICE_NAME_RU = {
    "haircut": "Стрижка",
    "manicure": "Маникюр",
    "massage": "Массаж",
    "back massage": "Массаж спины",
    "eyebrow shaping": "Оформление бровей",
    "hair coloring": "Окрашивание",
    "pedicure": "Педикюр",
    "facial treatment": "Уход за лицом",
    "gel nails": "Гель-наращивание",
    "makeup": "Макияж",
    "wedding makeup": "Свадебный макияж",
}

ALTERNATIVE_PROMPT = """\
Напиши ОДНО предложение на русском (до 15 слов) почему этот мастер — хороший второй вариант. \
ОБЯЗАТЕЛЬНО укажи цену в ₽ и расстояние в км из данных. \
НЕ используй жирный шрифт и звёздочки. Отвечай ТОЛЬКО одним предложением.\
"""

TRANSLATE_PROMPT = """\
Translate the following user query into a short English search phrase for a beauty services marketplace. \
Return ONLY the English keywords, nothing else. If the query is not about beauty services, \
return "NOT_BEAUTY" exactly. Examples:
- "я хочу подстричься" -> "haircut"
- "сделай мне маникюр" -> "manicure"
- "нужен массаж спины" -> "back massage"
- "макияж на свадьбу" -> "wedding makeup"
- "оформление бровей" -> "eyebrow shaping"
- "кладка плитки" -> "NOT_BEAUTY"
- "ремонт квартиры" -> "NOT_BEAUTY"\
"""


class SearchRequest(BaseModel):
    query: str
    latitude: float
    longitude: float
    radius_km: float = 50.0


class SearchResponse(BaseModel):
    answer: str
    masters: list[dict]


def _translate_service_name(name: str) -> str:
    """Translate English service name to Russian using lookup table."""
    lower = name.lower().strip()
    if lower in SERVICE_NAME_RU:
        return SERVICE_NAME_RU[lower]
    # If not found, return original (might already be Russian)
    return name


def _sort_masters(masters: list[dict]) -> list[dict]:
    """Sort masters by combined score: rating (50%) + experience (30%) + closeness (20%).
    Best master first."""
    if not masters:
        return masters

    # Normalize experience (max in list = 1.0)
    max_exp = max(m.get("experience", 0) for m in masters) or 1
    # Normalize distance inversely (closest = 1.0)
    max_dist = max(m.get("distance_km", 0) for m in masters) or 1

    def score(m: dict) -> float:
        rating_norm = float(m.get("rating", 0)) / 5.0  # 0..1
        exp_norm = float(m.get("experience", 0)) / max_exp  # 0..1
        dist_norm = 1.0 - (float(m.get("distance_km", 0)) / max_dist)  # closer = higher
        return rating_norm * 0.5 + exp_norm * 0.3 + dist_norm * 0.2

    return sorted(masters, key=score, reverse=True)


def _build_answer(masters: list[dict], alt_description: str) -> str:
    """Build the structured answer text server-side.
    This guarantees master #1 in text = master #1 in card list."""
    best = masters[0]
    prices = [float(m.get("price", 0)) for m in masters]
    min_price = int(min(prices)) if prices else 0

    service_name = _translate_service_name(best.get("service_name", ""))

    lines = [
        f"Я нашел {len(masters)} мастеров поблизости (цены от {min_price} ₽). Вот лучшие варианты:",
        "",
        f"🏆 {best['master_name']} — Лучший выбор",
        "",
        f"• Услуга: {service_name}",
        f"• Цена: {int(float(best['price']))} ₽",
        f"• Рейтинг: {best['rating']} ⭐ (стаж {best['experience']} лет)",
        f"• Идти: {best['distance_km']:.1f} км",
    ]

    if len(masters) >= 2:
        alt = masters[1]
        alt_name = _translate_service_name(alt.get("service_name", ""))
        lines.append("")
        lines.append(f"💡 {alt['master_name']} — Альтернатива")
        # Use LLM-generated description or fallback
        desc = alt_description.strip()
        if not desc:
            desc = (
                f"Хороший вариант за {int(float(alt['price']))} ₽, "
                f"расстояние {alt['distance_km']:.1f} км."
            )
        lines.append(desc)

    return "\n".join(lines)


@router.post("/search", response_model=SearchResponse)
async def search_services(req: SearchRequest, db: Client = Depends(get_supabase)):
    print(f"[SEARCH] query='{req.query}' lat={req.latitude} lon={req.longitude} radius={req.radius_km}")

    # 1. Translate query to English keywords via Groq
    english_query = await _translate_query(req.query)
    print(f"[SEARCH] translated='{english_query}'")

    if english_query == "NOT_BEAUTY":
        return SearchResponse(
            answer="SoloStyle — это маркетплейс бьюти-услуг (стрижки, маникюр, массаж, макияж, косметология). "
                   "К сожалению, я не могу помочь с этим запросом. Попробуйте найти мастера красоты! 💇‍♀️",
            masters=[],
        )

    # 2. Vectorize the English query
    query_embedding = embed_text(english_query)

    # 3. Call Supabase RPC function
    result = db.rpc("search_services", {
        "query_embedding": query_embedding,
        "user_lat": req.latitude,
        "user_lon": req.longitude,
        "max_distance_km": req.radius_km,
        "match_limit": 5,
    }).execute()

    # 4. Filter by similarity threshold
    MIN_SIMILARITY = 0.3
    masters_data = [m for m in (result.data or []) if m.get("similarity", 0) >= MIN_SIMILARITY]
    print(f"[SEARCH] found {len(result.data or [])} raw, {len(masters_data)} after filter (>= {MIN_SIMILARITY})")

    if not masters_data:
        return SearchResponse(
            answer="К сожалению, я не нашёл подходящих мастеров поблизости 😔\n"
                   "Попробуйте уточнить запрос или увеличить радиус поиска.",
            masters=[],
        )

    # 5. Sort masters: best first (rating + experience + closeness)
    masters_data = _sort_masters(masters_data)
    print(f"[SEARCH] sorted order: {[m['master_name'] for m in masters_data]}")

    # 6. Get LLM description for the alternative master (one sentence)
    alt_description = ""
    if len(masters_data) >= 2:
        alt = masters_data[1]
        alt_service_ru = _translate_service_name(alt.get("service_name", ""))
        alt_context = (
            f"Мастер: {alt['master_name']}, услуга: {alt_service_ru}, "
            f"цена: {int(float(alt['price']))} ₽, расстояние: {alt['distance_km']:.1f} км, "
            f"рейтинг: {alt['rating']}/5, стаж: {alt['experience']} лет."
        )
        try:
            alt_description = await _call_groq(alt_context, system_prompt=ALTERNATIVE_PROMPT)
        except Exception as e:
            print(f"[SEARCH] alt description error: {e}")
            alt_description = ""

    # 7. Build structured answer server-side (no LLM ordering issues)
    answer = _build_answer(masters_data, alt_description)
    print(f"[SEARCH] answer built, best={masters_data[0]['master_name']}")

    return SearchResponse(answer=answer, masters=masters_data)


async def _translate_query(query: str) -> str:
    """Translate user query to English keywords via Groq (fast, cheap)."""
    if not settings.groq_api_key:
        return query

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(
                "https://api.groq.com/openai/v1/chat/completions",
                headers={
                    "Authorization": f"Bearer {settings.groq_api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": "llama-3.1-8b-instant",
                    "messages": [
                        {"role": "system", "content": TRANSLATE_PROMPT},
                        {"role": "user", "content": query},
                    ],
                    "temperature": 0.0,
                    "max_tokens": 50,
                },
            )
        if response.status_code == 200:
            result = response.json()["choices"][0]["message"]["content"].strip()
            return result
    except Exception as e:
        print(f"[SEARCH] translation error: {e}")

    return query


async def _call_groq(user_message: str, system_prompt: str = ALTERNATIVE_PROMPT) -> str:
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
                "temperature": 0.5,
                "max_tokens": 100,
            },
        )

    if response.status_code != 200:
        raise HTTPException(
            status_code=502,
            detail=f"Groq API error: {response.status_code} — {response.text}",
        )

    data = response.json()
    return data["choices"][0]["message"]["content"]
