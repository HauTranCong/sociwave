from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import logging
import os
from app.api import monitoring, rules, config, auth
from app.scheduler import MonitoringScheduler, monitoring_scheduler as monitoring_scheduler_singleton
from app.core.database import engine
from app.models import models
from app.core.settings import settings

models.Base.metadata.create_all(bind=engine)

# Basic logging setup so scheduler messages show up in console/uvicorn logs.
# Adjust level via settings.LOG_LEVEL (e.g., INFO, WARNING, ERROR).
log_level_name = settings.LOG_LEVEL.upper() if hasattr(settings, 'LOG_LEVEL') else os.environ.get("LOG_LEVEL", "INFO").upper()
log_level = getattr(logging, log_level_name, logging.INFO)
logging.basicConfig(
    level=log_level,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)

app = FastAPI(title="SociWave Backend")

logger = logging.getLogger("sociwave.main")
logger.setLevel(log_level)
if not logger.handlers:
    handler = logging.StreamHandler()
    formatter = logging.Formatter("%(asctime)s [%(levelname)s] %(name)s: %(message)s")
    handler.setFormatter(formatter)
    logger.addHandler(handler)

# Allow frontend (served on localhost:8080) to call the API from the browser.
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:8080",
        "http://127.0.0.1:8080",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix="/api/auth", tags=["auth"])
app.include_router(monitoring.router, prefix="/api", tags=["monitoring"])
app.include_router(rules.router, prefix="/api", tags=["rules"])
app.include_router(config.router, prefix="/api", tags=["config"])

# Start monitoring scheduler only when enabled in settings. This prevents
# duplicate scheduler instances when running multiple uvicorn workers.
monitoring_scheduler = None
if settings.ENABLE_SCHEDULER:
    monitoring_scheduler = MonitoringScheduler()
    try:
        logger.info("Starting monitoring scheduler from main.py")
        monitoring_scheduler.start()
        logger.info("Monitoring scheduler started successfully")
    except Exception:
        logger.exception("Failed to start monitoring scheduler")
    else:
        # expose to module-level singleton
        try:
            # assign to the module-level variable so api endpoints can access
            import app.scheduler as _sched_mod
            _sched_mod.monitoring_scheduler = monitoring_scheduler
            logger.info("Monitoring scheduler singleton exposed to app.scheduler")
        except Exception:
            logger.exception("Failed to expose monitoring scheduler singleton")
else:
    logger.info("Scheduler disabled by settings; not starting MonitoringScheduler")


@app.get("/")
def read_root():
    return {"message": "Welcome to the SociWave API"}


@app.on_event('shutdown')
def shutdown_event():
    try:
        if monitoring_scheduler is not None:
            monitoring_scheduler.shutdown()
    except Exception:
        pass
