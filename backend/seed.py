"""
Seed script: 20 masters + 2-3 services each with vector embeddings.
Uses sentence-transformers (all-MiniLM-L6-v2) for local embedding generation.
Run: python seed.py
"""

import os
import random

from dotenv import load_dotenv
from sentence_transformers import SentenceTransformer
from supabase import create_client

load_dotenv()

db = create_client(os.environ["SUPABASE_URL"], os.environ["SUPABASE_KEY"])
model = SentenceTransformer("all-MiniLM-L6-v2")

# --- Moscow center: ~55.75, 37.62 with spread ---

MASTERS = [
    {"name": "Anna Petrova",     "experience": 12, "rating": 4.9, "lat": 55.7558, "lon": 37.6173},
    {"name": "Maria Ivanova",    "experience": 8,  "rating": 4.7, "lat": 55.7612, "lon": 37.6295},
    {"name": "Elena Sidorova",   "experience": 3,  "rating": 4.3, "lat": 55.7480, "lon": 37.6050},
    {"name": "Olga Kuznetsova",  "experience": 15, "rating": 5.0, "lat": 55.7700, "lon": 37.5950},
    {"name": "Natalia Popova",   "experience": 6,  "rating": 4.5, "lat": 55.7400, "lon": 37.6400},
    {"name": "Tatiana Morozova", "experience": 1,  "rating": 4.0, "lat": 55.7530, "lon": 37.6530},
    {"name": "Irina Volkova",    "experience": 10, "rating": 4.8, "lat": 55.7650, "lon": 37.5800},
    {"name": "Yulia Sokolova",   "experience": 4,  "rating": 4.4, "lat": 55.7350, "lon": 37.6250},
    {"name": "Svetlana Kozlova", "experience": 7,  "rating": 4.6, "lat": 55.7750, "lon": 37.6100},
    {"name": "Daria Novikova",   "experience": 2,  "rating": 4.1, "lat": 55.7450, "lon": 37.6550},
    {"name": "Victoria Orlova",  "experience": 9,  "rating": 4.7, "lat": 55.7590, "lon": 37.5700},
    {"name": "Anastasia Belova", "experience": 5,  "rating": 4.5, "lat": 55.7680, "lon": 37.6450},
    {"name": "Ksenia Fomina",    "experience": 11, "rating": 4.9, "lat": 55.7320, "lon": 37.6000},
    {"name": "Polina Egorova",   "experience": 0,  "rating": 3.8, "lat": 55.7510, "lon": 37.6700},
    {"name": "Alina Makarova",   "experience": 14, "rating": 5.0, "lat": 55.7800, "lon": 37.5850},
    {"name": "Diana Loginova",   "experience": 3,  "rating": 4.2, "lat": 55.7420, "lon": 37.5950},
    {"name": "Kristina Titova",  "experience": 6,  "rating": 4.6, "lat": 55.7570, "lon": 37.6350},
    {"name": "Ekaterina Rybina", "experience": 8,  "rating": 4.8, "lat": 55.7630, "lon": 37.5600},
    {"name": "Veronika Guseva",  "experience": 1,  "rating": 4.0, "lat": 55.7380, "lon": 37.6150},
    {"name": "Lyudmila Shamina", "experience": 13, "rating": 4.9, "lat": 55.7720, "lon": 37.6500},
]

SERVICES_POOL = [
    ("Women's Haircut", "Professional women's haircut with styling and blow-dry. Includes consultation on face shape and hair type."),
    ("Men's Haircut", "Classic or modern men's haircut. Includes wash, cut, and styling with professional products."),
    ("Hair Coloring", "Full hair coloring with premium ammonia-free dyes. Includes color consultation and aftercare advice."),
    ("Balayage", "Hand-painted balayage highlights for a natural sun-kissed look. Premium lightening products used."),
    ("Keratin Treatment", "Brazilian keratin smoothing treatment. Eliminates frizz and adds shine for up to 3 months."),
    ("Manicure", "Classic manicure with nail shaping, cuticle care, and gel polish application in any color."),
    ("Pedicure", "Relaxing pedicure with foot soak, exfoliation, nail care, and gel polish."),
    ("Gel Nails Extension", "Full set of sculpted gel nail extensions. Choose any shape and length with custom design."),
    ("Facial Cleansing", "Deep facial cleansing with ultrasonic peeling, extraction, and hydrating mask."),
    ("Anti-Age Facial", "Rejuvenating facial treatment with collagen mask, facial massage, and serum application."),
    ("Eyebrow Shaping", "Precision eyebrow shaping with wax or thread. Includes tinting for defined brows."),
    ("Eyelash Extensions", "Classic or volume eyelash extensions using premium synthetic mink lashes."),
    ("Makeup", "Professional makeup for any occasion. Includes primer, foundation, contouring, eyes, and lips."),
    ("Bridal Makeup", "Complete bridal makeup package with trial session. Long-lasting products for your special day."),
    ("Swedish Massage", "Full body relaxation massage using Swedish techniques. 60 minutes of pure relaxation."),
    ("Deep Tissue Massage", "Therapeutic deep tissue massage targeting muscle tension and chronic pain areas."),
    ("Body Wrap", "Detoxifying body wrap with algae or chocolate. Includes exfoliation and moisturizing."),
    ("Waxing Full Legs", "Full leg waxing with premium hypoallergenic warm wax. Smooth results for weeks."),
    ("Hair Styling Updo", "Elegant updo hairstyling for events, weddings, or special occasions."),
    ("Scalp Treatment", "Therapeutic scalp treatment for dandruff, dryness, or hair loss prevention."),
]

# Price ranges by experience level
def price_for(experience: int) -> float:
    base = random.uniform(1500, 3000) if experience < 3 else \
           random.uniform(2500, 5000) if experience < 8 else \
           random.uniform(4000, 8000)
    return round(base / 100) * 100  # round to nearest 100


def main():
    # Clean existing test data
    print("Cleaning old data...")
    db.table("services").delete().neq("id", "00000000-0000-0000-0000-000000000000").execute()
    db.table("masters").delete().neq("id", "00000000-0000-0000-0000-000000000000").execute()

    print(f"Generating embeddings for {len(SERVICES_POOL)} service descriptions...")
    descriptions = [s[1] for s in SERVICES_POOL]
    all_embeddings = model.encode(descriptions).tolist()
    embedding_map = {desc: emb for desc, emb in zip(descriptions, all_embeddings)}

    print(f"Creating {len(MASTERS)} masters with services...\n")

    for m in MASTERS:
        # Insert master
        result = db.table("masters").insert({
            "name": m["name"],
            "experience": m["experience"],
            "rating": m["rating"],
            "location": f"POINT({m['lon']} {m['lat']})",
        }).execute()

        master_id = result.data[0]["id"]
        num_services = random.choice([2, 2, 3])
        chosen = random.sample(SERVICES_POOL, num_services)

        for svc_name, svc_desc in chosen:
            price = price_for(m["experience"])
            embedding = embedding_map[svc_desc]

            db.table("services").insert({
                "master_id": master_id,
                "name": svc_name,
                "description": svc_desc,
                "price": price,
                "embedding": embedding,
            }).execute()

        svc_names = ", ".join(s[0] for s in chosen)
        print(f"  {m['name']} (exp:{m['experience']}y, rating:{m['rating']}) — {svc_names}")

    # Summary
    masters_count = len(db.table("masters").select("id").execute().data)
    services_count = len(db.table("services").select("id").execute().data)
    print(f"\nDone! {masters_count} masters, {services_count} services in database.")


if __name__ == "__main__":
    main()
