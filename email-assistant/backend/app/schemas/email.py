"""
schemas/email.py
================
Pydantic models that define the shape of data going IN and OUT of the API.
These are separate from the SQLAlchemy ORM models intentionally —
we control exactly what fields are exposed to the frontend.
"""

from pydantic import BaseModel, EmailStr
from datetime import datetime
from typing import Optional


class EmailBase(BaseModel):
    id: str
    subject: Optional[str] = None
    sender: str
    sender_email: str
    snippet: Optional[str] = None
    timestamp: datetime
    is_read: bool = False


class EmailResponse(EmailBase):
    """Full email record returned to frontend, including classification and all metadata."""
    thread_id: Optional[str] = None
    label: Optional[str] = None        # Injected from Classification table
    confidence: Optional[float] = None
    is_deleted: bool = False
    labels: Optional[str] = None       # Gmail labels, comma-joined
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


class EmailListResponse(BaseModel):
    """Paginated list response."""
    emails: list[EmailResponse]
    total: int
    page: int
    page_size: int
    next_page_token: Optional[str] = None
