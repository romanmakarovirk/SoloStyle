from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from supabase import Client

from app.database import get_supabase

router = APIRouter()


class ServiceCreate(BaseModel):
    master_id: UUID
    name: str
    description: str | None = None
    price: float


class ServiceResponse(BaseModel):
    id: UUID
    master_id: UUID
    name: str
    description: str | None
    price: float
    created_at: str
    updated_at: str


@router.get("/services")
def list_services(db: Client = Depends(get_supabase)):
    result = db.table("services").select("*").execute()
    return result.data


@router.get("/services/master/{master_id}")
def list_services_by_master(master_id: UUID, db: Client = Depends(get_supabase)):
    result = db.table("services").select("*").eq("master_id", str(master_id)).execute()
    return result.data


@router.get("/services/{service_id}")
def get_service(service_id: UUID, db: Client = Depends(get_supabase)):
    result = db.table("services").select("*").eq("id", str(service_id)).execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="Service not found")
    return result.data[0]


@router.post("/services", status_code=201)
def create_service(service: ServiceCreate, db: Client = Depends(get_supabase)):
    data = {
        "master_id": str(service.master_id),
        "name": service.name,
        "description": service.description,
        "price": service.price,
    }
    result = db.table("services").insert(data).execute()
    return result.data[0]
