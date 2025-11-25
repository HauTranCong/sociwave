import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import asyncio
from sqlalchemy.orm import Session
from app.core.database import SessionLocal, engine
from app.models import models
from app.services.auth_service import get_password_hash

def create_user():
    db: Session = SessionLocal()
    try:
        # Check if user already exists
        user = db.query(models.UserModel).filter(models.UserModel.username == "testuser").first()
        if user:
            print("User 'testuser' already exists.")
            return

        hashed_password = get_password_hash("harold")
        db_user = models.UserModel(username="harold", hashed_password=hashed_password)
        db.add(db_user)
        db.commit()
        db.refresh(db_user)
        print(f"User '{db_user.username}' created successfully.")
    finally:
        db.close()

if __name__ == "__main__":
    print("Creating database tables...")
    models.Base.metadata.create_all(bind=engine)
    print("Tables created.")
    
    print("Creating user...")
    create_user()
    
