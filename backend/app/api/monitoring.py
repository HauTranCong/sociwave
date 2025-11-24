from fastapi import APIRouter, Depends, BackgroundTasks
from app.services.monitor_service import MonitorService
from app.services.facebook_service import FacebookService
from app.services.config_service import ConfigService
from typing import List, Dict, Any
from app.models.models import Reel, Comment
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

def get_facebook_service(config_service: ConfigService = Depends(get_config_service)):
    config = config_service.load_config()
    return FacebookService(
        access_token=config.accessToken,
        page_id=config.pageId,
        version=config.version,
        reels_limit=config.reelsLimit,
        comments_limit=config.commentsLimit,
        replies_limit=config.repliesLimit,
    )

def get_monitor_service(facebook_service: FacebookService = Depends(get_facebook_service)):
    return MonitorService(facebook_service)

@router.post("/trigger-monitoring")
async def trigger_monitoring(
    background_tasks: BackgroundTasks,
    monitor_service: MonitorService = Depends(get_monitor_service),
    config_service: ConfigService = Depends(get_config_service)
):
    rules = config_service.load_rules()
    background_tasks.add_task(monitor_service.perform_monitoring_cycle, rules)
    return {"message": "Monitoring cycle triggered in the background."}

@router.get("/user-info", response_model=Dict[str, Any])
def get_user_info(facebook_service: FacebookService = Depends(get_facebook_service)):
    return facebook_service.get_user_info()

@router.get("/reels", response_model=List[Reel])
def get_reels(facebook_service: FacebookService = Depends(get_facebook_service)):
    return facebook_service.get_reels()

@router.get("/posts", response_model=List[Dict[str, Any]])
def get_posts(facebook_service: FacebookService = Depends(get_facebook_service)):
    return facebook_service.get_posts()

@router.get("/comments/{reel_id}", response_model=List[Comment])
def get_comments(reel_id: str, facebook_service: FacebookService = Depends(get_facebook_service)):
    return facebook_service.get_comments(reel_id)

@router.post("/reply")
def reply_to_comment(comment_id: str, message: str, facebook_service: FacebookService = Depends(get_facebook_service)):
    return facebook_service.reply_to_comment(comment_id, message)

@router.post("/send-private-reply")
def send_private_reply(comment_id: str, message: str, facebook_service: FacebookService = Depends(get_facebook_service)):
    return facebook_service.send_private_reply(comment_id, message)

@router.get("/test-connection", response_model=bool)
def test_connection(facebook_service: FacebookService = Depends(get_facebook_service)):
    return facebook_service.test_connection()
