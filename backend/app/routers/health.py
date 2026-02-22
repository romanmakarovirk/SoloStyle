from datetime import datetime, timezone

from fastapi import APIRouter, Depends
from supabase import Client

from app.database import get_supabase

router = APIRouter()


@router.get("/health")
def health():
    return {"status": "ok", "timestamp": datetime.now(timezone.utc).isoformat()}


@router.get("/health/db")
def health_db(db: Client = Depends(get_supabase)):
    try:
        result = db.table("masters").select("id").limit(1).execute()
        return {
            "status": "ok",
            "database": "connected",
            "tables": {"masters": True},
        }
    except Exception as e:
        return {
            "status": "error",
            "database": "disconnected",
            "detail": str(e),
        }
