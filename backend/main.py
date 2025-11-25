from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api import monitoring, rules, config, auth
from app.scheduler import MonitoringScheduler, monitoring_scheduler as monitoring_scheduler_singleton
import os
from app.core.database import engine
from app.models import models

models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="SociWave Backend")

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

# Start monitoring scheduler ONLY when explicitly enabled via env var.
# This prevents duplicate scheduler instances when running multiple uvicorn workers.
monitoring_scheduler = None
if os.environ.get('RUN_SCHEDULER', '').lower() == 'true':
    monitoring_scheduler = MonitoringScheduler()
    monitoring_scheduler.start()
    # expose to module-level singleton
    try:
        # assign to the module-level variable so api endpoints can access
        import app.scheduler as _sched_mod
        _sched_mod.monitoring_scheduler = monitoring_scheduler
    except Exception:
        pass


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
