from fastapi import APIRouter, Depends
from typing import Dict, List
from app.models.models import Rule as RuleSchema
from app.services.config_service import ConfigService
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

@router.get("/rules", response_model=List[RuleSchema])
def get_rules(config_service: ConfigService = Depends(get_config_service)):
    rules_dict = config_service.load_rules()
    return list(rules_dict.values())

@router.post("/rules")
def save_rules(rules: Dict[str, RuleSchema], config_service: ConfigService = Depends(get_config_service)):
    config_service.save_rules(rules)
    return {"message": "Rules saved successfully."}
