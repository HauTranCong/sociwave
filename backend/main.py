from fastapi import FastAPI, Response
from fastapi.middleware.cors import CORSMiddleware
import logging
import os
from app.api import monitoring, rules, config, auth
from app.api import metrics as metrics_api
from app.scheduler import MonitoringScheduler
from app.core.database import engine
from app.core.migrations import run_migrations
from app.models import models
from app.core.settings import settings
from prometheus_client import generate_latest, CONTENT_TYPE_LATEST


# Ensure legacy tables are migrated to user-scoped versions before creating metadata
run_migrations(engine)
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

# Allow frontend to call the API from the browser. Origins can be extended via env.
_default_frontend_origins = [
    "http://localhost:8080",
    "http://127.0.0.1:8080",
]
_configured_frontend_origins = getattr(settings, "FRONTEND_ORIGINS", [])
if _configured_frontend_origins:
    # dict.fromkeys preserves order while removing duplicates
    _allowed_origins = list(
        dict.fromkeys(_default_frontend_origins + _configured_frontend_origins)
    )
else:
    _allowed_origins = _default_frontend_origins

app.add_middleware(
    CORSMiddleware,
    allow_origins=_allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix="/api/auth", tags=["auth"])
app.include_router(monitoring.router, prefix="/api", tags=["monitoring"])
app.include_router(rules.router, prefix="/api", tags=["rules"])
app.include_router(config.router, prefix="/api", tags=["config"])
app.include_router(metrics_api.router, prefix="/api/metrics", tags=["metrics"])

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


@app.get('/metrics')
def metrics():
    """Expose Prometheus metrics for scraping."""
    data = generate_latest()
    return Response(content=data, media_type=CONTENT_TYPE_LATEST)


@app.on_event('shutdown')
def shutdown_event():
    try:
        if monitoring_scheduler is not None:
            monitoring_scheduler.shutdown()
    except Exception:
        pass
