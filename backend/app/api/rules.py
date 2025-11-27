from fastapi import APIRouter, Depends, Query
from typing import Dict, List
from app.models.models import Rule as RuleSchema
from app.services.config_service import ConfigService
from sqlalchemy.orm import Session
from app.core.database import SessionLocal
from app.api.auth import get_current_user

router = APIRouter()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def get_page_id(page_id: str = Query(..., description="Facebook Page ID to scope config/rules")):
    return page_id

def get_config_service(
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
    page_id: str = Depends(get_page_id),
):
    return ConfigService(db, user_id=current_user.id, page_id=page_id)

@router.get("/rules", response_model=List[RuleSchema])
def get_rules(config_service: ConfigService = Depends(get_config_service)):
    rules_dict = config_service.load_rules()
    return list(rules_dict.values())

@router.post("/rules")
def save_rules(rules: Dict[str, RuleSchema], config_service: ConfigService = Depends(get_config_service), _current_user=Depends(get_current_user)):
    config_service.save_rules(rules)
    return {"message": "Rules saved successfully."}
