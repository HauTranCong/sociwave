from fastapi import APIRouter, Depends, Query
from app.services.config_service import ConfigService
from app.models.models import Config as ConfigSchema
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

def get_config_service_no_page(
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    return ConfigService(db, user_id=current_user.id, page_id=None)

@router.get("/config", response_model=ConfigSchema)
def get_config(config_service: ConfigService = Depends(get_config_service)):
    return config_service.load_config()

@router.post("/config")
def save_config(
    config: ConfigSchema,
    config_service: ConfigService = Depends(get_config_service),
    _current_user=Depends(get_current_user),
):
    # Ensure page_id alignment with the scoped page
    if config.pageId and config.pageId != config_service.page_id:
        from fastapi import HTTPException, status
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Payload pageId does not match requested page_id",
        )
    if not config.pageId:
        # set pageId to requested scope if missing
        config.pageId = config_service.page_id
    config_service.save_config(config)
    return {"message": "Configuration saved successfully."}

@router.delete("/config")
def delete_config(
    config_service: ConfigService = Depends(get_config_service),
    _current_user=Depends(get_current_user),
):
    """Remove all configuration/rules for the scoped page in the database."""
    config_service.delete_page_scope()
    return {"message": "Configuration deleted successfully."}

@router.get("/config/pages")
def list_pages(config_service: ConfigService = Depends(get_config_service_no_page)):
    """List distinct page_ids that have config for the authenticated user."""
    return config_service.list_pages()
