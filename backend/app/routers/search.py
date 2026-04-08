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

# Demo masters data — used when Supabase is unavailable
# Coordinates spread across real Irkutsk locations (salons, malls, centers)
DEMO_MASTERS = {
    "haircut": [
        {
            "service_id": "demo-h1", "master_id": "demo-m1",
            "master_name": "Анна Петрова",
            "service_name": "haircut",
            "service_description": "Женские и мужские стрижки, укладка",
            "price": 1200, "rating": 4.9, "experience": 8,
            "distance_km": 1.2, "similarity": 0.95,
            "master_lat": 52.2832, "master_lon": 104.2810,  # ул. Карла Маркса
        },
        {
            "service_id": "demo-h2", "master_id": "demo-m2",
            "master_name": "Дмитрий Волков",
            "service_name": "haircut",
            "service_description": "Барбершоп, мужские стрижки и борода",
            "price": 900, "rating": 4.7, "experience": 5,
            "distance_km": 2.8, "similarity": 0.90,
            "master_lat": 52.2715, "master_lon": 104.3055,  # Академгородок
        },
        {
            "service_id": "demo-h3", "master_id": "demo-m3",
            "master_name": "Елена Сидорова",
            "service_name": "haircut",
            "service_description": "Топ-стилист, колорирование и креативные стрижки",
            "price": 1500, "rating": 4.8, "experience": 12,
            "distance_km": 3.5, "similarity": 0.85,
            "master_lat": 52.3173, "master_lon": 104.2565,  # Свердловский район
        },
    ],
    "manicure": [
        {
            "service_id": "demo-n1", "master_id": "demo-m4",
            "master_name": "Мария Козлова",
            "service_name": "manicure",
            "service_description": "Маникюр, гель-лак, дизайн ногтей",
            "price": 1800, "rating": 5.0, "experience": 6,
            "distance_km": 0.8, "similarity": 0.96,
            "master_lat": 52.2898, "master_lon": 104.2785,  # ТЦ Модный Квартал
        },
        {
            "service_id": "demo-n2", "master_id": "demo-m5",
            "master_name": "Ольга Новикова",
            "service_name": "manicure",
            "service_description": "Аппаратный маникюр, наращивание",
            "price": 1400, "rating": 4.8, "experience": 4,
            "distance_km": 2.1, "similarity": 0.91,
            "master_lat": 52.2635, "master_lon": 104.2718,  # Ново-Ленино
        },
        {
            "service_id": "demo-n3", "master_id": "demo-m6",
            "master_name": "Кристина Белова",
            "service_name": "manicure",
            "service_description": "Японский маникюр, SPA-уход для рук",
            "price": 2100, "rating": 4.9, "experience": 7,
            "distance_km": 4.0, "similarity": 0.84,
            "master_lat": 52.2520, "master_lon": 104.3390,  # Солнечный
        },
    ],
    "massage": [
        {
            "service_id": "demo-s1", "master_id": "demo-m7",
            "master_name": "Игорь Смирнов",
            "service_name": "massage",
            "service_description": "Классический и спортивный массаж",
            "price": 2500, "rating": 4.9, "experience": 10,
            "distance_km": 1.5, "similarity": 0.94,
            "master_lat": 52.2945, "master_lon": 104.2960,  # Центр, ул. Ленина
        },
        {
            "service_id": "demo-s2", "master_id": "demo-m8",
            "master_name": "Наталья Иванова",
            "service_name": "massage",
            "service_description": "Релакс-массаж, лимфодренажный, антицеллюлитный",
            "price": 2000, "rating": 4.7, "experience": 7,
            "distance_km": 3.2, "similarity": 0.88,
            "master_lat": 52.2380, "master_lon": 104.2495,  # Иркутск-2
        },
    ],
    "makeup": [
        {
            "service_id": "demo-k1", "master_id": "demo-m9",
            "master_name": "Виктория Лебедева",
            "service_name": "makeup",
            "service_description": "Свадебный и вечерний макияж, обучение",
            "price": 3000, "rating": 5.0, "experience": 9,
            "distance_km": 1.0, "similarity": 0.97,
            "master_lat": 52.2862, "master_lon": 104.2835,  # ул. Урицкого
        },
        {
            "service_id": "demo-k2", "master_id": "demo-m10",
            "master_name": "Алина Морозова",
            "service_name": "makeup",
            "service_description": "Повседневный и вечерний макияж",
            "price": 2200, "rating": 4.8, "experience": 5,
            "distance_km": 2.4, "similarity": 0.90,
            "master_lat": 52.3048, "master_lon": 104.2340,  # Глазковский мост
        },
        {
            "service_id": "demo-k3", "master_id": "demo-m11",
            "master_name": "Дарья Орлова",
            "service_name": "makeup",
            "service_description": "Визажист-стилист, фотосессии, подиум",
            "price": 3500, "rating": 4.6, "experience": 3,
            "distance_km": 5.1, "similarity": 0.82,
            "master_lat": 52.2478, "master_lon": 104.3572,  # Университетский
        },
    ],
    "eyebrow": [
        {
            "service_id": "demo-b1", "master_id": "demo-m12",
            "master_name": "Светлана Тихонова",
            "service_name": "eyebrow shaping",
            "service_description": "Оформление бровей, ламинирование, окрашивание",
            "price": 800, "rating": 4.9, "experience": 5,
            "distance_km": 0.6, "similarity": 0.95,
            "master_lat": 52.2910, "master_lon": 104.2860,  # ТЦ Jam Молл
        },
        {
            "service_id": "demo-b2", "master_id": "demo-m13",
            "master_name": "Юлия Кравцова",
            "service_name": "eyebrow shaping",
            "service_description": "Архитектура бровей, микроблейдинг",
            "price": 1500, "rating": 4.7, "experience": 4,
            "distance_km": 3.8, "similarity": 0.88,
            "master_lat": 52.2265, "master_lon": 104.2630,  # Рабочее
        },
    ],
    "pedicure": [
        {
            "service_id": "demo-p1", "master_id": "demo-m4",
            "master_name": "Мария Козлова",
            "service_name": "pedicure",
            "service_description": "Педикюр классический и аппаратный",
            "price": 2200, "rating": 5.0, "experience": 6,
            "distance_km": 0.8, "similarity": 0.93,
            "master_lat": 52.2898, "master_lon": 104.2785,
        },
    ],
    "hair coloring": [
        {
            "service_id": "demo-c1", "master_id": "demo-m3",
            "master_name": "Елена Сидорова",
            "service_name": "hair coloring",
            "service_description": "Окрашивание, мелирование, балаяж, шатуш",
            "price": 4500, "rating": 4.8, "experience": 12,
            "distance_km": 3.5, "similarity": 0.92,
            "master_lat": 52.3173, "master_lon": 104.2565,
        },
        {
            "service_id": "demo-c2", "master_id": "demo-m14",
            "master_name": "Татьяна Волошина",
            "service_name": "hair coloring",
            "service_description": "Колорист, сложное окрашивание",
            "price": 5000, "rating": 4.9, "experience": 9,
            "distance_km": 1.8, "similarity": 0.89,
            "master_lat": 52.2790, "master_lon": 104.2920,  # ул. Байкальская
        },
    ],
}

# Default fallback for unrecognized services
DEMO_DEFAULT = [
    {
        "service_id": "demo-d1", "master_id": "demo-m1",
        "master_name": "Анна Петрова",
        "service_name": "haircut",
        "service_description": "Стилист-парикмахер широкого профиля",
        "price": 1200, "rating": 4.9, "experience": 8,
        "distance_km": 1.2, "similarity": 0.80,
        "master_lat": 52.2832, "master_lon": 104.2810,
    },
    {
        "service_id": "demo-d2", "master_id": "demo-m4",
        "master_name": "Мария Козлова",
        "service_name": "manicure",
        "service_description": "Мастер маникюра и педикюра",
        "price": 1800, "rating": 5.0, "experience": 6,
        "distance_km": 0.8, "similarity": 0.75,
        "master_lat": 52.2898, "master_lon": 104.2785,
    },
]


def _get_demo_masters(english_query: str) -> list[dict]:
    """Find the best matching demo masters for a query."""
    query_lower = english_query.lower().strip()
    for key in DEMO_MASTERS:
        if key in query_lower or query_lower in key:
            return [dict(m) for m in DEMO_MASTERS[key]]
    return [dict(m) for m in DEMO_DEFAULT]


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
    return name


def _sort_masters(masters: list[dict]) -> list[dict]:
    """Sort masters by combined score: rating (50%) + experience (30%) + closeness (20%)."""
    if not masters:
        return masters

    max_exp = max(m.get("experience", 0) for m in masters) or 1
    max_dist = max(m.get("distance_km", 0) for m in masters) or 1

    def score(m: dict) -> float:
        rating_norm = float(m.get("rating", 0)) / 5.0
        exp_norm = float(m.get("experience", 0)) / max_exp
        dist_norm = 1.0 - (float(m.get("distance_km", 0)) / max_dist)
        return rating_norm * 0.5 + exp_norm * 0.3 + dist_norm * 0.2

    return sorted(masters, key=score, reverse=True)


def _build_answer(masters: list[dict], alt_description: str) -> str:
    """Build the structured answer text server-side."""
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
        lines.append("")
        lines.append(f"💡 {alt['master_name']} — Альтернатива")
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

    # 2. Try real Supabase search, fall back to demo data
    masters_data = None
    try:
        query_embedding = embed_text(english_query)

        result = db.rpc("search_services", {
            "query_embedding": query_embedding,
            "user_lat": req.latitude,
            "user_lon": req.longitude,
            "max_distance_km": req.radius_km,
            "match_limit": 5,
        }).execute()

        MIN_SIMILARITY = 0.3
        masters_data = [m for m in (result.data or []) if m.get("similarity", 0) >= MIN_SIMILARITY]
        print(f"[SEARCH] found {len(result.data or [])} raw, {len(masters_data)} after filter")
    except Exception as e:
        print(f"[SEARCH] Supabase/embedding error, using demo data: {type(e).__name__}: {e}")
        masters_data = None

    # Fallback to demo data if Supabase returned nothing or failed
    if not masters_data:
        masters_data = _get_demo_masters(english_query)
        print(f"[SEARCH] using demo data: {len(masters_data)} masters for '{english_query}'")

    if not masters_data:
        return SearchResponse(
            answer="К сожалению, я не нашёл подходящих мастеров поблизости 😔\n"
                   "Попробуйте уточнить запрос или увеличить радиус поиска.",
            masters=[],
        )

    # 3. Sort masters
    masters_data = _sort_masters(masters_data)
    print(f"[SEARCH] sorted: {[m['master_name'] for m in masters_data]}")

    # 4. Get LLM description for alternative
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

    # 5. Build answer
    answer = _build_answer(masters_data, alt_description)
    print(f"[SEARCH] answer built, best={masters_data[0]['master_name']}")

    return SearchResponse(answer=answer, masters=masters_data)


async def _translate_query(query: str) -> str:
    """Translate user query to English keywords via Groq."""
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
