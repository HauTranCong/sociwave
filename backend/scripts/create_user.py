import sys
import os
import argparse
from sqlalchemy.orm import Session

# Ensure backend package is importable when running as a script
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.core.database import SessionLocal, engine
from app.core.migrations import run_migrations
from app.models import models
from app.services.auth_service import get_password_hash


def create_user(username: str, password: str, theme_mode: str = "system"):
    if theme_mode not in ("light", "dark", "system"):
        raise ValueError("theme_mode must be one of: light, dark, system")

    db: Session = SessionLocal()
    try:
        # Check if user already exists
        user = db.query(models.UserModel).filter(models.UserModel.username == username).first()
        if user:
            print(f"User '{username}' already exists.")
            return

        hashed_password = get_password_hash(password)
        db_user = models.UserModel(username=username, hashed_password=hashed_password, theme_mode=theme_mode)
        db.add(db_user)
        db.commit()
        db.refresh(db_user)
        print(f"User '{db_user.username}' created successfully.")
    finally:
        db.close()


def parse_args():
    parser = argparse.ArgumentParser(description="Create a SociWave user")
    parser.add_argument("username", help="Username for the new user")
    parser.add_argument("password", help="Password for the new user")
    parser.add_argument(
        "--theme-mode",
        choices=["light", "dark", "system"],
        default="system",
        help="Preferred theme mode for the user (default: system)",
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()

    print("Running migrations and ensuring tables exist...")
    run_migrations(engine)
    models.Base.metadata.create_all(bind=engine)

    print(f"Creating user '{args.username}'...")
    create_user(args.username, args.password, theme_mode=args.theme_mode)

# python scripts/create_user.py alice supersecret --theme-mode dark
