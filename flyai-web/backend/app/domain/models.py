import uuid
from datetime import datetime
from typing import List, Optional
from sqlalchemy import Column, String, Boolean, DateTime, Date, ForeignKey, Integer, JSON
from sqlalchemy.dialects.postgresql import ARRAY, UUID
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship

class Base(DeclarativeBase):
    pass

class Profile(Base):
    __tablename__ = "profiles"

    id = Column(UUID(as_uuid=True), primary key=True, default=uuid.uuid4)
    full_name = Column(String, nullable=False)
    nationality = Column(String, nullable=True)
    degree_level = Column(String, nullable=True)
    field_of_study = Column(String, nullable=True)
    cv_url = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    swipes = relationship("Swipe", back_populates="profile", cascade="all, delete-orphan")
    applications = relationship("Application", back_populates="profile", cascade="all, delete-orphan")
    sessions = relationship("ChatSession", back_populates="profile", cascade="all, delete-orphan")


class Scholarship(Base):
    __tablename__ = "scholarships"

    id = Column(String, primary key=True)
    title = Column(String, nullable=False)
    provider = Column(String, nullable=False)
    url = Column(String, unique=True, nullable=False)
    country = Column(ARRAY(String), default=[])
    degree_level = Column(ARRAY(String), default=[])
    funding_type = Column(String, default="INCONNU")  # TOTAL | PARTIEL | INCONNU
    domaines = Column(ARRAY(String), default=[])
    description = Column(String, default="")
    avantages = Column(ARRAY(String), default=[])
    criteres = Column(ARRAY(String), default=[])
    deadline = Column(Date, nullable=True)
    image_url = Column(String, nullable=True)
    active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    swipes = relationship("Swipe", back_populates="scholarship", cascade="all, delete-orphan")
    applications = relationship("Application", back_populates="scholarship", cascade="all, delete-orphan")


class Swipe(Base):
    __tablename__ = "swipes"

    id = Column(UUID(as_uuid=True), primary key=True, default=uuid.uuid4)
    profile_id = Column(UUID(as_uuid=True), ForeignKey("profiles.id", ondelete="cascade"), nullable=False)
    scholarship_id = Column(String, ForeignKey("scholarships.id", ondelete="cascade"), nullable=False)
    direction = Column(String, nullable=False)  # 'right' (like) | 'left' (skip)
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    profile = relationship("Profile", back_populates="swipes")
    scholarship = relationship("Scholarship", back_populates="swipes")


class ChatSession(Base):
    __tablename__ = "chat_sessions"

    id = Column(UUID(as_uuid=True), primary key=True, default=uuid.uuid4)
    profile_id = Column(UUID(as_uuid=True), ForeignKey("profiles.id", ondelete="cascade"), nullable=False)
    category = Column(String, default="assistant")  # 'assistant' | 'agent'
    title = Column(String, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    profile = relationship("Profile", back_populates="sessions")
    messages = relationship("ChatMessage", back_populates="session", cascade="all, delete-orphan")


class ChatMessage(Base):
    __tablename__ = "chat_messages"

    id = Column(UUID(as_uuid=True), primary key=True, default=uuid.uuid4)
    session_id = Column(UUID(as_uuid=True), ForeignKey("chat_sessions.id", ondelete="cascade"), nullable=False)
    role = Column(String, nullable=False)  # 'user' | 'assistant'
    content = Column(String, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    session = relationship("ChatSession", back_populates="messages")


class Application(Base):
    __tablename__ = "applications"

    id = Column(UUID(as_uuid=True), primary key=True, default=uuid.uuid4)
    profile_id = Column(UUID(as_uuid=True), ForeignKey("profiles.id", ondelete="cascade"), nullable=False)
    scholarship_id = Column(String, ForeignKey("scholarships.id", ondelete="cascade"), nullable=False)
    status = Column(String, default="draft")  # draft | in_progress | submitted | accepted | rejected
    progress = Column(Integer, default=0)
    checklist = Column(JSON, default=dict)  # {"CV": false, "Passport": false...}
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    profile = relationship("Profile", back_populates="applications")
    scholarship = relationship("Scholarship", back_populates="applications")
