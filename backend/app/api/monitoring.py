from fastapi import APIRouter, Depends, BackgroundTasks
import logging
from app.services.monitor_service import MonitorService
from app.services.facebook_service import FacebookService
from app.services.config_service import ConfigService
from typing import List, Dict, Any
from app.models.models import Reel, Comment
from sqlalchemy.orm import Session
from app.core.database import SessionLocal
from app.api.auth import get_current_user

router = APIRouter()
logger = logging.getLogger(__name__)

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
    # If required config values are missing, raise a 400 so client gets a clear message
    if not config.accessToken or not config.pageId:
        from fastapi import HTTPException, status
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Facebook configuration is incomplete. Please set accessToken and pageId via /api/config.",
        )
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
    config_service: ConfigService = Depends(get_config_service),
    _current_user=Depends(get_current_user),
):
    rules = config_service.load_rules()
    logger.info(
        "Received /trigger-monitoring; queuing background task with %s rules",
        len(rules),
    )
    background_tasks.add_task(monitor_service.perform_monitoring_cycle, rules)
    logger.info("/trigger-monitoring background task queued")
    return {"message": "Monitoring cycle triggered in the background."}


@router.get('/monitoring/enabled')
def get_monitoring_enabled(config_service: ConfigService = Depends(get_config_service)):
    enabled = config_service.get_monitoring_enabled()
    return {'enabled': enabled}


@router.post('/monitoring/enabled')
def set_monitoring_enabled(enabled: bool, config_service: ConfigService = Depends(get_config_service), _current_user=Depends(get_current_user)):
    # Persist the monitoringEnabled flag in the config table
    config = config_service.load_config()
    cfg_dict = config.dict()
    cfg_dict['monitoringEnabled'] = 'true' if enabled else 'false'
    # Reuse Config schema to save (ConfigService.save_config expects Config pydantic model)
    # But Config Schema doesn't define monitoringEnabled; save directly into DB
    # Use the db from ConfigService to store the key
    # We will use save_config by building a Config object for known keys and then persisting the monitoring key manually
    # Simpler: directly interact with DB models
    db = config_service.db
    from app.models.models import ConfigModel
    db_config = db.query(ConfigModel).filter(ConfigModel.key == 'monitoringEnabled').first()
    if db_config:
        db_config.value = 'true' if enabled else 'false'
    else:
        db_config = ConfigModel(key='monitoringEnabled', value='true' if enabled else 'false')
        db.add(db_config)
    db.commit()

    return {'enabled': enabled}


@router.get('/monitoring/interval')
def get_monitoring_interval(config_service: ConfigService = Depends(get_config_service)):
    seconds = config_service.get_monitoring_interval_seconds(300)
    return {'interval_seconds': seconds}


@router.post('/monitoring/interval')
def set_monitoring_interval(interval_seconds: int, config_service: ConfigService = Depends(get_config_service), _current_user=Depends(get_current_user)):
    # Persist interval in seconds to config table
    db = config_service.db
    from app.models.models import ConfigModel
    db_config = db.query(ConfigModel).filter(ConfigModel.key == 'monitoringIntervalSeconds').first()
    if db_config:
        db_config.value = str(int(interval_seconds))
    else:
        db_config = ConfigModel(key='monitoringIntervalSeconds', value=str(int(interval_seconds)))
        db.add(db_config)
    db.commit()
    # If the scheduler singleton exists, reschedule job
    try:
        import app.scheduler as _sched_mod
        sched = getattr(_sched_mod, 'monitoring_scheduler', None)
        if sched is not None:
            sched.reschedule(int(interval_seconds))
    except Exception:
        pass
    return {'interval_seconds': int(interval_seconds)}


@router.get('/monitoring/status')
def monitoring_status(config_service: ConfigService = Depends(get_config_service), _current_user=Depends(get_current_user)):
    """Return runtime monitoring status for debugging/admins."""
    enabled = config_service.get_monitoring_enabled()
    interval = config_service.get_monitoring_interval_seconds(300)

    status = {
        'monitoring_enabled': enabled,
        'configured_interval_seconds': interval,
        'scheduler_running': False,
        'last_run_utc': None,
        'job_id': None,
    }

    try:
        import app.scheduler as _sched_mod
        sched = getattr(_sched_mod, 'monitoring_scheduler', None)
        if sched is not None:
            status['scheduler_running'] = True
            try:
                job = getattr(sched, 'job', None)
                if job is not None:
                    status['job_id'] = getattr(job, 'id', None)
            except Exception:
                pass

            # last_run may be a datetime attribute if scheduler implementation sets it
            last_run = getattr(sched, 'last_run', None)
            if last_run is not None:
                try:
                    status['last_run_utc'] = last_run.isoformat()
                except Exception:
                    status['last_run_utc'] = str(last_run)
    except Exception:
        # swallow import/runtime errors
        pass

    return status

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
def reply_to_comment(comment_id: str, message: str, facebook_service: FacebookService = Depends(get_facebook_service), _current_user=Depends(get_current_user)):
    return facebook_service.reply_to_comment(comment_id, message)

@router.post("/send-private-reply")
def send_private_reply(comment_id: str, message: str, facebook_service: FacebookService = Depends(get_facebook_service), _current_user=Depends(get_current_user)):
    return facebook_service.send_private_reply(comment_id, message)

@router.get("/test-connection", response_model=bool)
def test_connection(facebook_service: FacebookService = Depends(get_facebook_service)):
    return facebook_service.test_connection()
