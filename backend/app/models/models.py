from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime
from sqlalchemy import Column, String, Boolean, JSON, Integer
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
    object_id = Column(String, primary_key=True, index=True)
    match_words = Column(JSON)
    reply_message = Column(String)
    inbox_message = Column(String, nullable=True)
    enabled = Column(Boolean, default=False)

class ConfigModel(Base):
    __tablename__ = "config"
    id = Column(Integer, primary_key=True, autoincrement=True)
    key = Column(String, unique=True, index=True)
    value = Column(String)

class UserModel(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True)
    hashed_password = Column(String)
    theme_mode = Column(String, default='system')



