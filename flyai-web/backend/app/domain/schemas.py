from pydantic import BaseModel, ConfigDict
from datetime import date, datetime
from typing import List, Optional, Dict
from uuid import UUID

# --- Profile schemas ---
class ProfileBase(BaseModel):
    full_name: str
    nationality: Optional[str] = None
    degree_level: Optional[str] = None
    field_of_study: Optional[str] = None
    cv_url: Optional[str] = None

class ProfileCreate(ProfileBase):
    pass

class ProfileOut(ProfileBase):
    id: UUID
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)

# --- Scholarship schemas ---
class ScholarshipBase(BaseModel):
    id: str
    title: str
    provider: str
    url: str
    country: List[str]
    degree_level: List[str]
    funding_type: str
    domaines: List[str]
    description: str
    avantages: List[str]
    criteres: List[str]
    deadline: Optional[date] = None
    image_url: Optional[str] = None
    active: bool = True

class ScholarshipOut(ScholarshipBase):
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)

# --- Swipe schemas ---
class SwipeCreate(BaseModel):
    scholarship_id: str
    direction: str  # 'right' | 'left'

class SwipeOut(BaseModel):
    id: UUID
    profile_id: UUID
    scholarship_id: str
    direction: str
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)

# --- Chat schemas ---
class ChatMessageBase(BaseModel):
    content: str

class ChatMessageCreate(ChatMessageBase):
    session_id: UUID

class ChatMessageOut(ChatMessageBase):
    id: UUID
    session_id: UUID
    role: str
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)

class ChatSessionCreate(BaseModel):
    category: str = "assistant"  # 'assistant' | 'agent'
    title: str

class ChatSessionOut(BaseModel):
    id: UUID
    profile_id: UUID
    category: str
    title: str
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)

# --- Application schemas ---
class ApplicationCreate(BaseModel):
    scholarship_id: str

class ApplicationUpdate(BaseModel):
    status: Optional[str] = None
    progress: Optional[int] = None
    checklist: Optional[Dict[str, bool]] = None

class ApplicationOut(BaseModel):
    id: UUID
    profile_id: UUID
    scholarship_id: str
    status: str
    progress: int
    checklist: Dict[str, bool]
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)
