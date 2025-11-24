from fastapi import APIRouter, Depends, Depends
from app.services.config_service import ConfigService
from app.models.models import Config as ConfigSchema
from sqlalchemy.orm import Session
from app.core.database import SessionLocal

router = APIRouter()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def get_config_service(db: Session = Depends(get_db)):
    return ConfigService(db)

@router.get("/config", response_model=ConfigSchema)
def get_config(config_service: ConfigService = Depends(get_config_service)):
    return config_service.load_config()

@router.post("/config")
def save_config(config: ConfigSchema, config_service: ConfigService = Depends(get_config_service)):
    config_service.save_config(config)
    return {"message": "Configuration saved successfully."}
