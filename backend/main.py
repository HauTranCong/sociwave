from fastapi import FastAPI
from app.api import monitoring, rules, config, auth
from app.core.database import engine
from app.models import models

models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="SociWave Backend")

app.include_router(auth.router, prefix="/api/auth", tags=["auth"])
app.include_router(monitoring.router, prefix="/api", tags=["monitoring"])
app.include_router(rules.router, prefix="/api", tags=["rules"])
app.include_router(config.router, prefix="/api", tags=["config"])

@app.get("/")
def read_root():
    return {"message": "Welcome to the SociWave API"}
