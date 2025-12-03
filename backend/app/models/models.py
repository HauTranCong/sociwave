from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime
from sqlalchemy import Column, String, Boolean, JSON, Integer, UniqueConstraint
from app.core.database import Base

# Pydantic models for external data (Facebook API)
class Reel(BaseModel):
    id: str
    description: Optional[str] = None
    updated_time: datetime
    has_rule: bool = Field(False, exclude=True)
    rule_enabled: bool = Field(False, exclude=True)

    class Config:
        from_attributes = True

class CommentAuthor(BaseModel):
    id: str
    name: str

    class Config:
        from_attributes = True

class Comment(BaseModel):
    id: str
    message: str
    from_user: Optional[CommentAuthor] = Field(None, alias='from')
    created_time: datetime
    updated_time: Optional[datetime] = None
    replies: Optional[List['Comment']] = None
    reply_count: Optional[int] = Field(None, exclude=True)
    has_replied: bool = Field(False, exclude=True)

    class Config:
        from_attributes = True
        populate_by_name = True

# --- Pydantic Schemas for our API (for request/response) ---
class Rule(BaseModel):
    object_id: str
    match_words: List[str] = []
    reply_message: str
    inbox_message: Optional[str] = None
    enabled: bool = False

    class Config:
        from_attributes = True

class Config(BaseModel):
    accessToken: str
    pageId: str
    version: str = "v20.0"
    useMockData: bool = False
    reelsLimit: int = 25
    commentsLimit: int = 100
    repliesLimit: int = 100

    class Config:
        from_attributes = True


# --- SQLAlchemy Models for Database ---
class RuleModel(Base):
    __tablename__ = "rules"
    user_id = Column(Integer, primary_key=True, index=True)
    page_id = Column(String, primary_key=True, index=True)
    object_id = Column(String, primary_key=True, index=True)
    match_words = Column(JSON)
    reply_message = Column(String)
    inbox_message = Column(String, nullable=True)
    enabled = Column(Boolean, default=False)

class ConfigModel(Base):
    __tablename__ = "config"
    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, index=True, nullable=False)
    page_id = Column(String, index=True, nullable=False, default="default")
    key = Column(String, index=True)
    value = Column(String)
    __table_args__ = (UniqueConstraint('user_id', 'page_id', 'key', name='uq_config_user_page_key'),)

class UserModel(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True)
    hashed_password = Column(String)
    theme_mode = Column(String, default='system')


class MonitoringMetric(Base):
    __tablename__ = "monitoring_metrics"
    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, index=True, nullable=True)
    page_id = Column(String, index=True, nullable=True)
    start_time = Column(String, nullable=False)
    duration_seconds = Column(String, nullable=False)
    reels_scanned = Column(Integer, default=0)
    # number of reels actively processed (had an enabled rule and were acted upon)
    reels_active = Column(Integer, default=0)
    comments_scanned = Column(Integer, default=0)
    replies_sent = Column(Integer, default=0)
    inbox_sent = Column(Integer, default=0)
    api_calls = Column(Integer, default=0)
