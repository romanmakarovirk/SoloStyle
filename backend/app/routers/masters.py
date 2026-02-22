from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from supabase import Client

from app.database import get_supabase

router = APIRouter()


class MasterCreate(BaseModel):
    name: str
    experience: int = 0
    rating: float = 0.0
    latitude: float | None = None
    longitude: float | None = None


class MasterResponse(BaseModel):
    id: UUID
    name: str
    experience: int
    rating: float
    location: str | None = None
    created_at: str
    updated_at: str


@router.get("/masters")
def list_masters(db: Client = Depends(get_supabase)):
    result = db.table("masters").select("*").execute()
    return result.data


@router.get("/masters/{master_id}")
def get_master(master_id: UUID, db: Client = Depends(get_supabase)):
    result = db.table("masters").select("*").eq("id", str(master_id)).execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="Master not found")
    return result.data[0]


@router.post("/masters", status_code=201)
def create_master(master: MasterCreate, db: Client = Depends(get_supabase)):
    data = {
        "name": master.name,
        "experience": master.experience,
        "rating": master.rating,
    }
    if master.latitude is not None and master.longitude is not None:
        data["location"] = f"POINT({master.longitude} {master.latitude})"

    result = db.table("masters").insert(data).execute()
    return result.data[0]
