#!/usr/bin/env bash
# =============================================================================
#  AI-Powered Personal Email Assistant — Project Setup Script
#  Run:  chmod +x setup.sh && ./setup.sh
#  Tested on: macOS 13+, Ubuntu 22+
# =============================================================================

set -e  # Exit immediately on any error

# ── Colours for pretty output ─────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log()  { echo -e "${GREEN}✔${NC}  $1"; }
warn() { echo -e "${YELLOW}⚠${NC}  $1"; }
info() { echo -e "${CYAN}→${NC}  $1"; }
head() { echo -e "\n${BOLD}${BLUE}▸ $1${NC}"; }
die()  { echo -e "${RED}✖  $1${NC}"; exit 1; }

echo -e "${BOLD}${CYAN}"
echo "  ╔═══════════════════════════════════════════════╗"
echo "  ║   AI-Powered Personal Email Assistant         ║"
echo "  ║   Project Scaffolding Script                  ║"
echo "  ╚═══════════════════════════════════════════════╝"
echo -e "${NC}"

# ── Prerequisite checks ───────────────────────────────────────────────────────
head "Checking prerequisites"

command -v python3 &>/dev/null || die "python3 not found. Install Python 3.10+."
command -v pip3   &>/dev/null || die "pip3 not found."
command -v node   &>/dev/null || die "node not found. Install Node.js 18+."
command -v npm    &>/dev/null || die "npm not found."

PY_VER=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
NODE_VER=$(node -e 'process.stdout.write(process.versions.node)')
log "Python $PY_VER found"
log "Node $NODE_VER found"

# ── Root folder ───────────────────────────────────────────────────────────────
PROJECT_ROOT="email-assistant"
if [ -d "$PROJECT_ROOT" ]; then
  warn "Directory '$PROJECT_ROOT' already exists. Files will be overwritten."
fi
mkdir -p "$PROJECT_ROOT"
cd "$PROJECT_ROOT"
log "Created project root: $(pwd)"


# =============================================================================
#  BACKEND — FastAPI
# =============================================================================
head "Scaffolding backend"

# Directory tree
mkdir -p backend/app/{api,services,models,schemas,db,utils}
mkdir -p backend/tests

# ── requirements.txt ──────────────────────────────────────────────────────────
cat > backend/requirements.txt << 'EOF'
fastapi==0.111.0
uvicorn[standard]==0.29.0
sqlalchemy==2.0.30
alembic==1.13.1
pydantic==2.7.1
pydantic-settings==2.2.1
python-dotenv==1.0.1
google-auth==2.29.0
google-auth-oauthlib==1.2.0
google-auth-httplib2==0.2.0
google-api-python-client==2.127.0
httpx==0.27.0
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4
scikit-learn==1.5.0
numpy==1.26.4
pytest==8.2.0
pytest-asyncio==0.23.7
EOF
log "requirements.txt"

# ── .env template ─────────────────────────────────────────────────────────────
cat > backend/.env << 'EOF'
# ─────────────────────────────────────────────
#  FILL IN THESE VALUES BEFORE RUNNING THE APP
#  Get credentials from: https://console.cloud.google.com
# ─────────────────────────────────────────────

# Google OAuth
GOOGLE_CLIENT_ID=your_google_client_id_here
GOOGLE_CLIENT_SECRET=your_google_client_secret_here
GOOGLE_REDIRECT_URI=http://localhost:8000/api/v1/auth/callback

# App
SECRET_KEY=change_this_to_a_long_random_string_32chars_min
FRONTEND_URL=http://localhost:5173
DATABASE_URL=sqlite:///./email_assistant.db

# Optional: set to "production" when deploying
ENVIRONMENT=development
EOF
log ".env template"

# ── backend/app/__init__.py ───────────────────────────────────────────────────
touch backend/app/__init__.py
touch backend/app/api/__init__.py
touch backend/app/services/__init__.py
touch backend/app/models/__init__.py
touch backend/app/schemas/__init__.py
touch backend/app/db/__init__.py
touch backend/app/utils/__init__.py
touch backend/tests/__init__.py

# ── config.py ─────────────────────────────────────────────────────────────────
cat > backend/app/config.py << 'EOF'
"""
config.py
=========
Central configuration using Pydantic BaseSettings.
All values are read from environment variables (or .env file).
Import `settings` anywhere in the app — never read os.environ directly.
"""

from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    # Google OAuth 2.0
    google_client_id: str = ""
    google_client_secret: str = ""
    google_redirect_uri: str = "http://localhost:8000/api/v1/auth/callback"

    # Gmail scopes required by our app
    google_scopes: list[str] = [
        "https://www.googleapis.com/auth/gmail.readonly",
        "https://www.googleapis.com/auth/gmail.modify",
        "openid",
        "email",
        "profile",
    ]

    # Application
    secret_key: str = "changeme"
    frontend_url: str = "http://localhost:5173"
    database_url: str = "sqlite:///./email_assistant.db"
    environment: str = "development"

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


@lru_cache()  # Singleton — settings object is created once and reused
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
EOF
log "config.py"

# ── db/database.py ────────────────────────────────────────────────────────────
cat > backend/app/db/database.py << 'EOF'
"""
db/database.py
==============
SQLAlchemy engine and session factory.
FastAPI routes use `get_db()` as a dependency to obtain a session,
which is automatically closed after the request completes.
"""

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase
from app.config import settings

# connect_args is only needed for SQLite (prevents threading issues)
connect_args = {"check_same_thread": False} if "sqlite" in settings.database_url else {}

engine = create_engine(
    settings.database_url,
    connect_args=connect_args,
    echo=(settings.environment == "development"),  # Log SQL in dev only
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


class Base(DeclarativeBase):
    """All ORM models inherit from this Base."""
    pass


def get_db():
    """
    FastAPI dependency that yields a DB session.
    Usage:  db: Session = Depends(get_db)
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
EOF
log "db/database.py"

# ── db/init_db.py ─────────────────────────────────────────────────────────────
cat > backend/app/db/init_db.py << 'EOF'
"""
db/init_db.py
=============
Creates all tables on application startup.
In production you would use Alembic migrations instead.
"""

from app.db.database import engine, Base
# Import models so SQLAlchemy knows about them before calling create_all
from app.models import email, classification, behavior_log, sender_score  # noqa: F401


def init_db() -> None:
    """Create all tables if they don't already exist."""
    Base.metadata.create_all(bind=engine)
    print("✔  Database tables created / verified.")
EOF
log "db/init_db.py"

# ── models/email.py ───────────────────────────────────────────────────────────
cat > backend/app/models/email.py << 'EOF'
"""
models/email.py
===============
Stores email metadata fetched from Gmail.
We deliberately avoid storing full email bodies to keep the DB lightweight.
"""

from sqlalchemy import Column, String, DateTime, Boolean, Text, Index
from sqlalchemy.sql import func
from app.db.database import Base


class Email(Base):
    __tablename__ = "emails"

    id           = Column(String, primary_key=True)   # Gmail message ID
    thread_id    = Column(String, index=True)
    subject      = Column(String, nullable=True)
    sender       = Column(String, index=True)          # "Name <email@example.com>"
    sender_email = Column(String, index=True)          # Extracted email address only
    snippet      = Column(Text, nullable=True)         # First ~150 chars of body
    timestamp    = Column(DateTime(timezone=True))
    is_read      = Column(Boolean, default=False)
    is_deleted   = Column(Boolean, default=False)
    labels       = Column(String, nullable=True)       # Raw Gmail labels, comma-joined

    # Audit
    created_at   = Column(DateTime(timezone=True), server_default=func.now())
    updated_at   = Column(DateTime(timezone=True), onupdate=func.now())

    __table_args__ = (
        Index("ix_emails_timestamp", "timestamp"),
    )
EOF
log "models/email.py"

# ── models/classification.py ──────────────────────────────────────────────────
cat > backend/app/models/classification.py << 'EOF'
"""
models/classification.py
=========================
Stores the AI/rule classification result for each email.
Keeping this separate from the Email model allows us to re-classify
emails as the model improves without touching the raw data.
"""

from sqlalchemy import Column, String, Float, DateTime, ForeignKey, Boolean
from sqlalchemy.sql import func
from app.db.database import Base


class Classification(Base):
    __tablename__ = "classifications"

    id            = Column(String, primary_key=True)  # Same as email.id
    email_id      = Column(String, ForeignKey("emails.id"), unique=True, index=True)

    # Label: "important" | "promotions" | "spam" | "social" | "updates"
    label         = Column(String, nullable=False, index=True)
    confidence    = Column(Float, default=0.0)   # 0.0 – 1.0

    # Source of classification: "rules" | "ml" | "user_override"
    source        = Column(String, default="rules")
    is_overridden = Column(Boolean, default=False)  # True if user corrected us

    created_at    = Column(DateTime(timezone=True), server_default=func.now())
    updated_at    = Column(DateTime(timezone=True), onupdate=func.now())
EOF
log "models/classification.py"

# ── models/behavior_log.py ────────────────────────────────────────────────────
cat > backend/app/models/behavior_log.py << 'EOF'
"""
models/behavior_log.py
======================
Append-only log of every user action.
This is the raw data that feeds the Behavior Engine.
Actions: "open" | "delete" | "archive" | "mark_important" | "ignore" | "unsubscribe"
"""

from sqlalchemy import Column, String, DateTime, ForeignKey, Index
from sqlalchemy.sql import func
from app.db.database import Base


class BehaviorLog(Base):
    __tablename__ = "behavior_logs"

    id         = Column(String, primary_key=True)   # UUID generated at insert time
    email_id   = Column(String, ForeignKey("emails.id"), index=True)
    sender     = Column(String, index=True)          # Denormalised for fast aggregation
    action     = Column(String, nullable=False)      # See docstring above
    timestamp  = Column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        Index("ix_behavior_sender_action", "sender", "action"),
    )
EOF
log "models/behavior_log.py"

# ── models/sender_score.py ────────────────────────────────────────────────────
cat > backend/app/models/sender_score.py << 'EOF'
"""
models/sender_score.py
======================
Learned importance score per sender.
Updated incrementally every time a behavior event is logged.
Score range: -10 (always spam/ignored) to +10 (always important/opened).
"""

from sqlalchemy import Column, String, Float, Integer, DateTime
from sqlalchemy.sql import func
from app.db.database import Base


class SenderScore(Base):
    __tablename__ = "sender_scores"

    sender_email  = Column(String, primary_key=True)
    display_name  = Column(String, nullable=True)

    # Computed scores
    importance_score = Column(Float, default=0.0)   # -10 to +10
    open_count       = Column(Integer, default=0)
    delete_count     = Column(Integer, default=0)
    ignore_count     = Column(Integer, default=0)
    total_received   = Column(Integer, default=0)

    last_seen   = Column(DateTime(timezone=True), nullable=True)
    updated_at  = Column(DateTime(timezone=True), onupdate=func.now())
    created_at  = Column(DateTime(timezone=True), server_default=func.now())
EOF
log "models/sender_score.py"

# ── schemas/email.py ──────────────────────────────────────────────────────────
cat > backend/app/schemas/email.py << 'EOF'
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
    """Full email record returned to frontend, including classification."""
    label: Optional[str] = None        # Injected from Classification table
    confidence: Optional[float] = None

    model_config = {"from_attributes": True}


class EmailListResponse(BaseModel):
    """Paginated list response."""
    emails: list[EmailResponse]
    total: int
    page: int
    page_size: int
    next_page_token: Optional[str] = None
EOF
log "schemas/email.py"

# ── schemas/classification.py ─────────────────────────────────────────────────
cat > backend/app/schemas/classification.py << 'EOF'
from pydantic import BaseModel
from typing import Literal


class ClassifyRequest(BaseModel):
    email_id: str
    # Optionally force a label (user override)
    override_label: Literal["important", "promotions", "spam", "social", "updates"] | None = None


class ClassifyResponse(BaseModel):
    email_id: str
    label: str
    confidence: float
    source: str
EOF
log "schemas/classification.py"

# ── schemas/behavior.py ───────────────────────────────────────────────────────
cat > backend/app/schemas/behavior.py << 'EOF'
from pydantic import BaseModel
from typing import Literal
from datetime import datetime


class BehaviorLogRequest(BaseModel):
    email_id: str
    action: Literal["open", "delete", "archive", "mark_important", "ignore", "unsubscribe"]


class BehaviorLogResponse(BaseModel):
    logged: bool
    sender_score_updated: bool


class SuggestionItem(BaseModel):
    sender_email: str
    display_name: str | None
    suggestion: str          # e.g. "Auto-delete? You've ignored 14 emails from this sender."
    action: str              # "auto_delete" | "unsubscribe"
    confidence: float


class InsightsSummary(BaseModel):
    total_emails: int
    important: int
    promotions: int
    spam: int
    unread: int
    top_senders: list[dict]
    suggestions: list[SuggestionItem]
    week_over_week_change: float  # % change in total volume
EOF
log "schemas/behavior.py"

# ── utils/email_parser.py ─────────────────────────────────────────────────────
cat > backend/app/utils/email_parser.py << 'EOF'
"""
utils/email_parser.py
=====================
Parses raw Gmail API message payloads into clean Python dicts.
Gmail's payload format is deeply nested — this module hides that complexity
from the rest of the application.
"""

import re
import base64
from datetime import datetime, timezone
from typing import Optional


def extract_sender_email(sender_string: str) -> str:
    """
    Extract bare email from strings like 'John Doe <john@example.com>'
    or just 'john@example.com'.
    """
    match = re.search(r"<([^>]+)>", sender_string)
    if match:
        return match.group(1).lower().strip()
    return sender_string.lower().strip()


def parse_gmail_timestamp(internal_date: str) -> datetime:
    """
    Gmail returns internalDate as milliseconds since epoch (as a string).
    """
    ts_seconds = int(internal_date) / 1000
    return datetime.fromtimestamp(ts_seconds, tz=timezone.utc)


def get_header(headers: list[dict], name: str) -> Optional[str]:
    """Find a header value by name (case-insensitive) from Gmail headers list."""
    for h in headers:
        if h.get("name", "").lower() == name.lower():
            return h.get("value")
    return None


def parse_message(raw_message: dict) -> dict:
    """
    Transform a raw Gmail API message object into a flat dict
    suitable for inserting into our Email model.

    Args:
        raw_message: The dict returned by gmail.users().messages().get()

    Returns:
        Flat dict with keys: id, thread_id, subject, sender, sender_email,
                             snippet, timestamp, is_read, labels
    """
    headers = raw_message.get("payload", {}).get("headers", [])
    label_ids = raw_message.get("labelIds", [])

    sender_raw = get_header(headers, "from") or ""
    timestamp_raw = raw_message.get("internalDate", "0")

    return {
        "id":           raw_message["id"],
        "thread_id":    raw_message.get("threadId", ""),
        "subject":      get_header(headers, "subject") or "(no subject)",
        "sender":       sender_raw,
        "sender_email": extract_sender_email(sender_raw),
        "snippet":      raw_message.get("snippet", "")[:300],   # cap at 300 chars
        "timestamp":    parse_gmail_timestamp(timestamp_raw),
        "is_read":      "UNREAD" not in label_ids,
        "is_deleted":   "TRASH" in label_ids,
        "labels":       ",".join(label_ids),
    }
EOF
log "utils/email_parser.py"

# ── utils/token_store.py ──────────────────────────────────────────────────────
cat > backend/app/utils/token_store.py << 'EOF'
"""
utils/token_store.py
====================
Simple file-based OAuth token store for MVP.
In production, replace with encrypted DB storage per user.

The token is stored as a JSON file at ./tokens/user_token.json
(gitignored). This is intentionally simple for Phase 1.
"""

import json
import os
from pathlib import Path
from google.oauth2.credentials import Credentials
from app.config import settings

TOKEN_DIR  = Path("./tokens")
TOKEN_FILE = TOKEN_DIR / "user_token.json"


def save_token(credentials: Credentials) -> None:
    """Persist OAuth credentials to disk."""
    TOKEN_DIR.mkdir(exist_ok=True)
    token_data = {
        "token":         credentials.token,
        "refresh_token": credentials.refresh_token,
        "token_uri":     credentials.token_uri,
        "client_id":     credentials.client_id,
        "client_secret": credentials.client_secret,
        "scopes":        credentials.scopes,
    }
    TOKEN_FILE.write_text(json.dumps(token_data, indent=2))


def load_token() -> Credentials | None:
    """Load credentials from disk. Returns None if not found."""
    if not TOKEN_FILE.exists():
        return None
    data = json.loads(TOKEN_FILE.read_text())
    return Credentials(
        token=data["token"],
        refresh_token=data.get("refresh_token"),
        token_uri=data.get("token_uri", "https://oauth2.googleapis.com/token"),
        client_id=data.get("client_id", settings.google_client_id),
        client_secret=data.get("client_secret", settings.google_client_secret),
        scopes=data.get("scopes", settings.google_scopes),
    )


def delete_token() -> None:
    """Remove stored token (used on logout)."""
    if TOKEN_FILE.exists():
        TOKEN_FILE.unlink()
EOF
log "utils/token_store.py"

# ── services/gmail_service.py ────────────────────────────────────────────────
cat > backend/app/services/gmail_service.py << 'EOF'
"""
services/gmail_service.py
==========================
All communication with the Gmail API lives here.
Routes should NEVER import googleapiclient directly — they always go through this service.

Key design decisions:
  - Returns clean Python dicts/lists, never raw API objects
  - Handles token refresh transparently
  - Pagination is handled internally via next_page_token
"""

from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from google.auth.transport.requests import Request as GoogleRequest
from app.utils.token_store import load_token, save_token
from app.utils.email_parser import parse_message
from typing import Optional
import logging

logger = logging.getLogger(__name__)


def _get_gmail_service():
    """
    Build and return an authenticated Gmail API service object.
    Automatically refreshes expired tokens.
    Raises ValueError if the user hasn't authenticated yet.
    """
    credentials = load_token()
    if not credentials:
        raise ValueError("User not authenticated. Please complete OAuth flow first.")

    # Refresh access token if it's expired
    if credentials.expired and credentials.refresh_token:
        credentials.refresh(GoogleRequest())
        save_token(credentials)  # Persist the refreshed token

    return build("gmail", "v1", credentials=credentials)


def fetch_emails(
    max_results: int = 50,
    page_token: Optional[str] = None,
    query: str = "",
) -> dict:
    """
    Fetch emails from Gmail inbox.

    Args:
        max_results:  Number of emails to return (max 500 per Gmail API limits)
        page_token:   Token for fetching the next page of results
        query:        Gmail search query string (e.g. "is:unread", "from:boss@co.com")

    Returns:
        {
          "emails": [parsed_email_dict, ...],
          "next_page_token": str | None,
          "result_size_estimate": int
        }
    """
    service = _get_gmail_service()

    # Step 1: Get list of message IDs matching the query
    list_response = service.users().messages().list(
        userId="me",
        maxResults=min(max_results, 500),
        pageToken=page_token,
        q=query or "in:inbox",
    ).execute()

    message_stubs = list_response.get("messages", [])

    if not message_stubs:
        return {"emails": [], "next_page_token": None, "result_size_estimate": 0}

    # Step 2: Fetch full metadata for each message ID
    # We use 'metadata' format to avoid downloading full bodies
    emails = []
    for stub in message_stubs:
        try:
            raw = service.users().messages().get(
                userId="me",
                id=stub["id"],
                format="metadata",
                metadataHeaders=["From", "Subject", "Date"],
            ).execute()
            emails.append(parse_message(raw))
        except HttpError as e:
            logger.warning(f"Failed to fetch message {stub['id']}: {e}")
            continue

    return {
        "emails": emails,
        "next_page_token": list_response.get("nextPageToken"),
        "result_size_estimate": list_response.get("resultSizeEstimate", 0),
    }


def trash_email(message_id: str) -> bool:
    """Move a single email to trash. Returns True on success."""
    try:
        service = _get_gmail_service()
        service.users().messages().trash(userId="me", id=message_id).execute()
        return True
    except HttpError as e:
        logger.error(f"Failed to trash message {message_id}: {e}")
        return False


def mark_as_read(message_id: str) -> bool:
    """Remove the UNREAD label from a message."""
    try:
        service = _get_gmail_service()
        service.users().messages().modify(
            userId="me",
            id=message_id,
            body={"removeLabelIds": ["UNREAD"]},
        ).execute()
        return True
    except HttpError as e:
        logger.error(f"Failed to mark {message_id} as read: {e}")
        return False


def batch_trash(message_ids: list[str]) -> dict:
    """
    Trash multiple emails. Returns a summary of successes and failures.
    Used by the 'one-click cleanup' feature.
    """
    results = {"success": [], "failed": []}
    for mid in message_ids:
        if trash_email(mid):
            results["success"].append(mid)
        else:
            results["failed"].append(mid)
    return results
EOF
log "services/gmail_service.py"

# ── services/classifier.py ────────────────────────────────────────────────────
cat > backend/app/services/classifier.py << 'EOF'
"""
services/classifier.py
=======================
Email classification engine — Phase 1 uses rules, Phase 2 blends in sender scores.

Classification labels:
  "important"   — Emails the user likely needs to act on
  "promotions"  — Marketing, newsletters, deals
  "spam"        — Likely junk
  "social"      — Social network notifications
  "updates"     — Transactional (receipts, shipping, account notices)

How the scoring works:
  1. Rule-based signals each add or subtract from a score per category
  2. Sender score (from behavior_tracker) is added as a learned signal
  3. The category with the highest score wins

This is intentionally simple — no external ML model is required.
The "learning" comes from the sender_score table, which is updated
every time the user interacts with an email.
"""

import re
from dataclasses import dataclass, field
from app.models.sender_score import SenderScore
from sqlalchemy.orm import Session
import logging

logger = logging.getLogger(__name__)


# ── Keyword patterns for rule-based scoring ───────────────────────────────────

PROMOTION_KEYWORDS = [
    r"\bsale\b", r"\bdiscount\b", r"\boffer\b", r"\bpromo\b",
    r"\bunsubscribe\b", r"\bnewsletter\b", r"\b\d+%\s*off\b",
    r"\bdeal\b", r"\blimited time\b", r"\bfree shipping\b",
    r"\bclick here\b", r"\bopt.out\b",
]

SPAM_KEYWORDS = [
    r"\bviagra\b", r"\bcasino\b", r"\blottery\b", r"\bwon\b.*\bprize\b",
    r"\burgent\b.*\baction\b", r"\bverify your account\b",
    r"\bclaim your reward\b", r"\byou.ve been selected\b",
    r"\bmake money\b", r"\bwork from home\b",
]

SOCIAL_DOMAINS = [
    "facebook.com", "twitter.com", "instagram.com", "linkedin.com",
    "tiktok.com", "reddit.com", "pinterest.com", "nextdoor.com",
]

UPDATE_KEYWORDS = [
    r"\breceipt\b", r"\border\b.*\bconfirm", r"\bshipping\b",
    r"\bdelivered\b", r"\binvoice\b", r"\bstatement\b",
    r"\bpassword\b.*\breset\b", r"\bverification code\b",
    r"\byour account\b",
]

IMPORTANT_SIGNALS = [
    r"\baction required\b", r"\bimportant\b", r"\burgent\b",
    r"\bfyi\b", r"\bfollowing up\b", r"\bmeeting\b", r"\binterview\b",
    r"\bdeadline\b", r"\bplease review\b",
]


@dataclass
class ClassificationResult:
    label: str
    confidence: float
    source: str = "rules"
    scores: dict = field(default_factory=dict)  # Full score breakdown for debugging


def _count_pattern_matches(text: str, patterns: list[str]) -> int:
    """Count how many regex patterns match in a text string."""
    text_lower = text.lower()
    return sum(1 for p in patterns if re.search(p, text_lower))


def classify_email(
    email_data: dict,
    db: Session | None = None,
) -> ClassificationResult:
    """
    Classify a single email.

    Args:
        email_data: Dict with keys: subject, sender, sender_email, snippet, labels
        db:         Optional DB session. If provided, sender scores are incorporated.

    Returns:
        ClassificationResult with label, confidence, and raw scores.
    """
    subject      = email_data.get("subject", "") or ""
    sender       = email_data.get("sender", "") or ""
    sender_email = email_data.get("sender_email", "") or ""
    snippet      = email_data.get("snippet", "") or ""
    gmail_labels = email_data.get("labels", "") or ""

    # Combined text blob for keyword matching
    full_text = f"{subject} {snippet}"

    # ── Phase 0: Trust Gmail's own labels first ───────────────────────────────
    if "SPAM" in gmail_labels:
        return ClassificationResult(label="spam", confidence=0.95, source="gmail_label")
    if "CATEGORY_PROMOTIONS" in gmail_labels:
        return ClassificationResult(label="promotions", confidence=0.90, source="gmail_label")
    if "CATEGORY_SOCIAL" in gmail_labels:
        return ClassificationResult(label="social", confidence=0.90, source="gmail_label")
    if "CATEGORY_UPDATES" in gmail_labels:
        return ClassificationResult(label="updates", confidence=0.85, source="gmail_label")
    if "IMPORTANT" in gmail_labels:
        # Gmail flagged as important, but still run our own scoring
        pass

    # ── Phase 1: Rule-based scoring ───────────────────────────────────────────
    scores = {
        "important":  0.0,
        "promotions": 0.0,
        "spam":       0.0,
        "social":     0.0,
        "updates":    0.0,
    }

    # Score promotions
    promo_hits = _count_pattern_matches(full_text, PROMOTION_KEYWORDS)
    scores["promotions"] += promo_hits * 1.5

    # Score spam
    spam_hits = _count_pattern_matches(full_text, SPAM_KEYWORDS)
    scores["spam"] += spam_hits * 2.0

    # Score social
    sender_domain = sender_email.split("@")[-1] if "@" in sender_email else ""
    if any(d in sender_domain for d in SOCIAL_DOMAINS):
        scores["social"] += 4.0

    # Score updates
    update_hits = _count_pattern_matches(full_text, UPDATE_KEYWORDS)
    scores["updates"] += update_hits * 1.5

    # Score important
    important_hits = _count_pattern_matches(full_text, IMPORTANT_SIGNALS)
    scores["important"] += important_hits * 2.0
    if "IMPORTANT" in gmail_labels:
        scores["important"] += 3.0

    # ── Phase 2: Blend in learned sender score ────────────────────────────────
    if db and sender_email:
        sender_record = db.query(SenderScore).filter(
            SenderScore.sender_email == sender_email
        ).first()

        if sender_record:
            learned_score = sender_record.importance_score  # -10 to +10
            # Positive score boosts "important", negative boosts "spam/promotions"
            if learned_score > 0:
                scores["important"] += learned_score * 0.8
            elif learned_score < -3:
                scores["spam"] += abs(learned_score) * 0.5
            elif learned_score < 0:
                scores["promotions"] += abs(learned_score) * 0.4

    # ── Determine winner ──────────────────────────────────────────────────────
    # Default to "updates" if no strong signal
    if max(scores.values()) < 1.0:
        return ClassificationResult(
            label="updates", confidence=0.5, source="default", scores=scores
        )

    winner = max(scores, key=scores.get)
    total  = sum(scores.values()) or 1
    confidence = min(scores[winner] / total, 0.99)

    source = "rules" if db is None else "rules+behavior"

    return ClassificationResult(
        label=winner,
        confidence=round(confidence, 3),
        source=source,
        scores=scores,
    )


def classify_batch(emails: list[dict], db: Session | None = None) -> list[ClassificationResult]:
    """Classify a list of emails. Returns results in the same order."""
    return [classify_email(e, db=db) for e in emails]
EOF
log "services/classifier.py"

# ── services/behavior_tracker.py ──────────────────────────────────────────────
cat > backend/app/services/behavior_tracker.py << 'EOF'
"""
services/behavior_tracker.py
============================
Records user interactions with emails and updates sender importance scores.

Score update formula (exponential moving average style):
  - "open"           → +1.0
  - "mark_important" → +2.0
  - "archive"        → +0.3
  - "ignore"         → -0.5
  - "delete"         → -1.0
  - "unsubscribe"    → -2.0

Scores are clamped to [-10, +10].

The SenderScore table is the "memory" of the system. Over time,
senders the user always opens get positive scores; senders they always
delete get negative scores. The classifier then uses these scores.
"""

import uuid
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from app.models.behavior_log import BehaviorLog
from app.models.sender_score import SenderScore
from app.models.email import Email
import logging

logger = logging.getLogger(__name__)

# How much each action shifts the importance score
ACTION_WEIGHTS = {
    "open":           +1.0,
    "mark_important": +2.0,
    "archive":        +0.3,
    "ignore":         -0.5,
    "delete":         -1.0,
    "unsubscribe":    -2.0,
}

SCORE_MIN = -10.0
SCORE_MAX = +10.0
LEARNING_RATE = 0.3   # How quickly new behavior overrides old score (0 = no learning, 1 = replace)


def log_action(email_id: str, action: str, db: Session) -> bool:
    """
    Record a user action and update the sender's importance score.

    Args:
        email_id: The Gmail message ID
        action:   One of the keys in ACTION_WEIGHTS
        db:       Active SQLAlchemy session

    Returns:
        True if the sender score was updated, False if the email wasn't found.
    """
    if action not in ACTION_WEIGHTS:
        logger.warning(f"Unknown action: {action}")
        return False

    # Look up the email to get the sender
    email = db.query(Email).filter(Email.id == email_id).first()
    if not email:
        logger.warning(f"Email {email_id} not found in DB, cannot log action.")
        return False

    # 1. Append to the behavior log (immutable audit trail)
    log_entry = BehaviorLog(
        id=str(uuid.uuid4()),
        email_id=email_id,
        sender=email.sender_email,
        action=action,
        timestamp=datetime.now(timezone.utc),
    )
    db.add(log_entry)

    # 2. Update sender score (upsert)
    _update_sender_score(email.sender_email, email.sender, action, db)

    db.commit()
    return True


def _update_sender_score(
    sender_email: str,
    display_name: str,
    action: str,
    db: Session,
) -> None:
    """
    Apply an exponential moving average update to the sender's importance score.
    Creates the record if it doesn't exist yet.
    """
    record = db.query(SenderScore).filter(
        SenderScore.sender_email == sender_email
    ).first()

    weight = ACTION_WEIGHTS.get(action, 0.0)

    if record is None:
        # First time we've seen this sender
        record = SenderScore(
            sender_email=sender_email,
            display_name=display_name,
            importance_score=weight,
            open_count=0,
            delete_count=0,
            ignore_count=0,
            total_received=0,
            last_seen=datetime.now(timezone.utc),
        )
        db.add(record)
    else:
        # Exponential moving average: new_score = old + lr * (signal - old)
        # This means frequent behavior has diminishing returns — the score
        # stabilises rather than drifting to the extremes.
        record.importance_score += LEARNING_RATE * (weight - record.importance_score * 0.1)
        record.importance_score = max(SCORE_MIN, min(SCORE_MAX, record.importance_score))
        record.last_seen = datetime.now(timezone.utc)

    # Increment the relevant counter
    if action == "open":
        record.open_count += 1
    elif action == "delete":
        record.delete_count += 1
    elif action == "ignore":
        record.ignore_count += 1

    record.total_received += 1


def get_suggestions(db: Session, threshold_ignores: int = 5) -> list[dict]:
    """
    Return a list of action suggestions based on learned behavior.
    Currently surfaces:
      - Senders with many ignores / deletes → suggest auto-delete
      - Senders with very negative scores  → suggest unsubscribe

    Args:
        db:                Active DB session
        threshold_ignores: Min ignore count to trigger a suggestion

    Returns:
        List of suggestion dicts.
    """
    suggestions = []

    # Senders the user consistently ignores or deletes
    candidates = db.query(SenderScore).filter(
        (SenderScore.ignore_count >= threshold_ignores) |
        (SenderScore.importance_score <= -3.0)
    ).order_by(SenderScore.importance_score).limit(10).all()

    for c in candidates:
        if c.ignore_count >= threshold_ignores:
            suggestions.append({
                "sender_email":  c.sender_email,
                "display_name":  c.display_name or c.sender_email,
                "suggestion":    f"You've ignored {c.ignore_count} emails from this sender. Auto-delete future emails?",
                "action":        "auto_delete",
                "confidence":    min(c.ignore_count / 20, 0.95),
            })
        elif c.importance_score <= -5.0:
            suggestions.append({
                "sender_email":  c.sender_email,
                "display_name":  c.display_name or c.sender_email,
                "suggestion":    f"This sender has a very low importance score ({c.importance_score:.1f}). Unsubscribe?",
                "action":        "unsubscribe",
                "confidence":    0.80,
            })

    return suggestions
EOF
log "services/behavior_tracker.py"

# ── services/insights_service.py ──────────────────────────────────────────────
cat > backend/app/services/insights_service.py << 'EOF'
"""
services/insights_service.py
============================
Aggregates data from all tables to produce dashboard metrics.
All queries here are read-only — no data is modified.
"""

from sqlalchemy.orm import Session
from sqlalchemy import func, and_
from datetime import datetime, timedelta, timezone
from app.models.email import Email
from app.models.classification import Classification
from app.models.sender_score import SenderScore
from app.services.behavior_tracker import get_suggestions


def get_summary(db: Session) -> dict:
    """Return the full dashboard summary."""
    # Total email count
    total = db.query(func.count(Email.id)).scalar() or 0
    unread = db.query(func.count(Email.id)).filter(Email.is_read == False).scalar() or 0

    # Count by classification label
    label_counts = dict(
        db.query(Classification.label, func.count(Classification.email_id))
        .group_by(Classification.label)
        .all()
    )

    # Top 10 senders by total received
    top_senders = (
        db.query(SenderScore)
        .order_by(SenderScore.total_received.desc())
        .limit(10)
        .all()
    )

    top_senders_list = [
        {
            "sender_email":    s.sender_email,
            "display_name":    s.display_name or s.sender_email,
            "total_received":  s.total_received,
            "importance_score": round(s.importance_score, 2),
            "open_rate": round(s.open_count / s.total_received, 2) if s.total_received else 0,
        }
        for s in top_senders
    ]

    # Week-over-week volume change
    now     = datetime.now(timezone.utc)
    one_week_ago  = now - timedelta(days=7)
    two_weeks_ago = now - timedelta(days=14)

    this_week  = db.query(func.count(Email.id)).filter(Email.timestamp >= one_week_ago).scalar() or 0
    last_week  = db.query(func.count(Email.id)).filter(
        and_(Email.timestamp >= two_weeks_ago, Email.timestamp < one_week_ago)
    ).scalar() or 0
    wow_change = ((this_week - last_week) / last_week * 100) if last_week > 0 else 0.0

    # Pull suggestions from behavior tracker
    suggestions = get_suggestions(db)

    return {
        "total_emails":       total,
        "unread":             unread,
        "important":          label_counts.get("important", 0),
        "promotions":         label_counts.get("promotions", 0),
        "spam":               label_counts.get("spam", 0),
        "social":             label_counts.get("social", 0),
        "updates":            label_counts.get("updates", 0),
        "top_senders":        top_senders_list,
        "suggestions":        suggestions,
        "week_over_week_change": round(wow_change, 1),
    }
EOF
log "services/insights_service.py"

# ── api/auth.py ───────────────────────────────────────────────────────────────
cat > backend/app/api/auth.py << 'EOF'
"""
api/auth.py
===========
Handles the Google OAuth 2.0 flow.

Flow:
  1. Frontend hits GET /auth/login  → redirects to Google consent screen
  2. Google redirects to GET /auth/callback?code=...
  3. We exchange the code for tokens, save them, redirect to frontend
"""

from fastapi import APIRouter
from fastapi.responses import RedirectResponse
from google_auth_oauthlib.flow import Flow
from app.config import settings
from app.utils.token_store import save_token, delete_token
import os

router = APIRouter(prefix="/auth", tags=["Authentication"])

# Allow HTTP for local development (OAuth normally requires HTTPS)
os.environ.setdefault("OAUTHLIB_INSECURE_TRANSPORT", "1")


def _build_flow() -> Flow:
    """Create the OAuth flow object from our credentials."""
    return Flow.from_client_config(
        client_config={
            "web": {
                "client_id":     settings.google_client_id,
                "client_secret": settings.google_client_secret,
                "auth_uri":      "https://accounts.google.com/o/oauth2/auth",
                "token_uri":     "https://oauth2.googleapis.com/token",
                "redirect_uris": [settings.google_redirect_uri],
            }
        },
        scopes=settings.google_scopes,
        redirect_uri=settings.google_redirect_uri,
    )


@router.get("/login")
def login():
    """
    Step 1: Generate the Google OAuth URL and redirect the user to it.
    The `access_type=offline` param ensures we get a refresh_token.
    """
    flow = _build_flow()
    auth_url, _ = flow.authorization_url(
        access_type="offline",
        include_granted_scopes="true",
        prompt="consent",  # Force consent screen so we always get refresh_token
    )
    return RedirectResponse(url=auth_url)


@router.get("/callback")
def callback(code: str, state: str | None = None):
    """
    Step 2: Google redirects here after the user consents.
    We exchange the authorization code for access + refresh tokens.
    """
    flow = _build_flow()
    flow.fetch_token(code=code)
    save_token(flow.credentials)

    # Redirect user back to the React app
    return RedirectResponse(url=f"{settings.frontend_url}/dashboard")


@router.post("/logout")
def logout():
    """Delete stored token and redirect to login."""
    delete_token()
    return {"message": "Logged out successfully."}


@router.get("/status")
def auth_status():
    """Check if a token file exists (user is logged in)."""
    from app.utils.token_store import load_token
    creds = load_token()
    return {"authenticated": creds is not None}
EOF
log "api/auth.py"

# ── api/emails.py ─────────────────────────────────────────────────────────────
cat > backend/app/api/emails.py << 'EOF'
"""
api/emails.py
=============
Email fetch and storage endpoints.
Routes are intentionally thin — they delegate to services.
"""

from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.orm import Session
from app.db.database import get_db
from app.services import gmail_service
from app.services.classifier import classify_email
from app.models.email import Email
from app.models.classification import Classification
from app.schemas.email import EmailListResponse, EmailResponse
import uuid

router = APIRouter(prefix="/emails", tags=["Emails"])


@router.post("/sync")
def sync_emails(
    max_results: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
):
    """
    Fetch emails from Gmail, store them in DB, and classify each one.
    This is the main 'sync' operation — call it to refresh the inbox.

    Returns a summary of what was fetched and classified.
    """
    try:
        result = gmail_service.fetch_emails(max_results=max_results)
    except ValueError as e:
        raise HTTPException(status_code=401, detail=str(e))

    raw_emails = result["emails"]
    synced = 0

    for email_data in raw_emails:
        # Upsert email record
        existing = db.query(Email).filter(Email.id == email_data["id"]).first()
        if not existing:
            db.add(Email(**email_data))
            synced += 1

            # Classify and store result
            clf = classify_email(email_data, db=db)
            db.add(Classification(
                id=str(uuid.uuid4()),
                email_id=email_data["id"],
                label=clf.label,
                confidence=clf.confidence,
                source=clf.source,
            ))

    db.commit()

    return {
        "fetched":  len(raw_emails),
        "new":      synced,
        "next_page_token": result["next_page_token"],
    }


@router.get("", response_model=EmailListResponse)
def list_emails(
    page: int  = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    label: str | None = Query(None, description="Filter by classification label"),
    db: Session = Depends(get_db),
):
    """
    List stored emails with optional label filter and pagination.
    Joins classification data so each email includes its label.
    """
    query = (
        db.query(Email, Classification)
        .outerjoin(Classification, Email.id == Classification.email_id)
        .filter(Email.is_deleted == False)
    )

    if label:
        query = query.filter(Classification.label == label)

    total = query.count()
    rows  = query.order_by(Email.timestamp.desc()) \
                 .offset((page - 1) * page_size) \
                 .limit(page_size) \
                 .all()

    emails = []
    for email, clf in rows:
        e = EmailResponse(
            id=email.id,
            subject=email.subject,
            sender=email.sender,
            sender_email=email.sender_email,
            snippet=email.snippet,
            timestamp=email.timestamp,
            is_read=email.is_read,
            label=clf.label if clf else None,
            confidence=clf.confidence if clf else None,
        )
        emails.append(e)

    return EmailListResponse(emails=emails, total=total, page=page, page_size=page_size)


@router.delete("/{email_id}")
def delete_email(email_id: str, db: Session = Depends(get_db)):
    """Trash an email both in Gmail and in our DB."""
    success = gmail_service.trash_email(email_id)
    if success:
        email = db.query(Email).filter(Email.id == email_id).first()
        if email:
            email.is_deleted = True
            db.commit()
    return {"success": success}
EOF
log "api/emails.py"

# ── api/behavior.py ───────────────────────────────────────────────────────────
cat > backend/app/api/behavior.py << 'EOF'
"""
api/behavior.py
===============
Endpoints for logging user actions and fetching suggestions.
"""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.db.database import get_db
from app.services import behavior_tracker
from app.schemas.behavior import BehaviorLogRequest, BehaviorLogResponse

router = APIRouter(prefix="/behavior", tags=["Behavior"])


@router.post("/log", response_model=BehaviorLogResponse)
def log_behavior(body: BehaviorLogRequest, db: Session = Depends(get_db)):
    """
    Log a user action (open, delete, ignore, etc.) for an email.
    Automatically updates the sender's importance score.
    """
    updated = behavior_tracker.log_action(
        email_id=body.email_id,
        action=body.action,
        db=db,
    )
    return BehaviorLogResponse(logged=True, sender_score_updated=updated)


@router.get("/suggestions")
def get_suggestions(db: Session = Depends(get_db)):
    """Return AI-generated suggestions based on learned behavior patterns."""
    suggestions = behavior_tracker.get_suggestions(db)
    return {"suggestions": suggestions}
EOF
log "api/behavior.py"

# ── api/insights.py ───────────────────────────────────────────────────────────
cat > backend/app/api/insights.py << 'EOF'
"""
api/insights.py
===============
Dashboard metrics and summary data.
"""

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.database import get_db
from app.services import insights_service

router = APIRouter(prefix="/insights", tags=["Insights"])


@router.get("/summary")
def get_summary(db: Session = Depends(get_db)):
    """
    Return the full dashboard summary:
    - Email counts by category
    - Top senders
    - Week-over-week change
    - Suggestions
    """
    return insights_service.get_summary(db)
EOF
log "api/insights.py"

# ── main.py ───────────────────────────────────────────────────────────────────
cat > backend/app/main.py << 'EOF'
"""
main.py
=======
FastAPI application entry point.
Registers all routers, configures CORS, and initialises the database on startup.

To run:  uvicorn app.main:app --reload  (from the backend/ directory)
Docs at: http://localhost:8000/docs
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.config import settings
from app.db.init_db import init_db
from app.api import auth, emails, behavior, insights

app = FastAPI(
    title="AI Email Assistant API",
    version="1.0.0",
    description="Backend for the AI-Powered Personal Email Assistant",
)

# ── CORS ──────────────────────────────────────────────────────────────────────
# Allow the React dev server to talk to the API without CORS errors
app.add_middleware(
    CORSMiddleware,
    allow_origins=[settings.frontend_url, "http://localhost:5173"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Routers ───────────────────────────────────────────────────────────────────
API_PREFIX = "/api/v1"
app.include_router(auth.router,     prefix=API_PREFIX)
app.include_router(emails.router,   prefix=API_PREFIX)
app.include_router(behavior.router, prefix=API_PREFIX)
app.include_router(insights.router, prefix=API_PREFIX)


# ── Startup ───────────────────────────────────────────────────────────────────
@app.on_event("startup")
def on_startup():
    """Create DB tables when the server starts (idempotent)."""
    init_db()


@app.get("/health")
def health_check():
    """Simple health check — used by load balancers and Docker healthchecks."""
    return {"status": "ok", "version": "1.0.0"}
EOF
log "main.py"

# ── run.py ────────────────────────────────────────────────────────────────────
cat > backend/run.py << 'EOF'
"""Entry point for running the backend server."""
import uvicorn

if __name__ == "__main__":
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)
EOF
log "run.py"

# ── tests ─────────────────────────────────────────────────────────────────────
cat > backend/tests/test_classifier.py << 'EOF'
"""Unit tests for the classifier — no DB or API required."""
import pytest
from app.services.classifier import classify_email


def test_classifies_spam():
    email = {"subject": "You won the lottery! Claim your prize now", "snippet": "", "sender": "noreply@spam.biz", "sender_email": "noreply@spam.biz", "labels": ""}
    result = classify_email(email)
    assert result.label == "spam"


def test_classifies_promotions():
    email = {"subject": "50% off sale — limited time deal!", "snippet": "Unsubscribe here", "sender": "deals@shop.com", "sender_email": "deals@shop.com", "labels": ""}
    result = classify_email(email)
    assert result.label == "promotions"


def test_classifies_social():
    email = {"subject": "John liked your post", "snippet": "", "sender": "noreply@facebook.com", "sender_email": "noreply@facebook.com", "labels": ""}
    result = classify_email(email)
    assert result.label == "social"


def test_trusts_gmail_spam_label():
    email = {"subject": "Hello", "snippet": "", "sender": "a@b.com", "sender_email": "a@b.com", "labels": "SPAM"}
    result = classify_email(email)
    assert result.label == "spam"
    assert result.source == "gmail_label"
EOF
log "tests/test_classifier.py"


# =============================================================================
#  FRONTEND — React + Vite
# =============================================================================
head "Scaffolding frontend"

# Manually create frontend folder + package.json
# (avoids interactive prompts from `npm create vite`)
mkdir -p frontend/src frontend/public
cd frontend

cat > package.json << 'PKGJSON'
{
  "name": "email-assistant-frontend",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev":     "vite",
    "build":   "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "axios":            "^1.7.2",
    "date-fns":         "^3.6.0",
    "lucide-react":     "^0.383.0",
    "react":            "^18.3.1",
    "react-dom":        "^18.3.1",
    "react-router-dom": "^6.23.1",
    "recharts":         "^2.12.7",
    "zustand":          "^4.5.2"
  },
  "devDependencies": {
    "@types/react":            "^18.3.3",
    "@types/react-dom":        "^18.3.0",
    "@vitejs/plugin-react":    "^4.3.0",
    "autoprefixer":            "^10.4.19",
    "postcss":                 "^8.4.38",
    "tailwindcss":             "^3.4.4",
    "vite":                    "^5.3.1"
  }
}
PKGJSON
log "package.json"

# Write index.html (Vite entry point)
cat > index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>MailMind — AI Email Assistant</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
HTMLEOF
log "index.html"

# Write vite.config.js
cat > vite.config.js << 'VITEEOF'
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  server: { port: 5173 },
});
VITEEOF
log "vite.config.js"

# Write postcss.config.js
cat > postcss.config.js << 'POSTCSSEOF'
export default {
  plugins: { tailwindcss: {}, autoprefixer: {} },
};
POSTCSSEOF
log "postcss.config.js"

# Install all packages in one shot (faster, no interactive prompts)
echo ""
info "Running npm install — this may take 2-3 minutes..."
npm install --no-fund --no-audit 2>&1 | tail -5
log "npm packages installed"

# ── tailwind.config.js ───────────────────────────────────────────────────────
cat > tailwind.config.js << 'EOF'
/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
  theme: {
    extend: {
      fontFamily: {
        sans: ["'DM Sans'", "system-ui", "sans-serif"],
        mono: ["'JetBrains Mono'", "monospace"],
      },
      colors: {
        brand: {
          50:  "#f0f4ff",
          100: "#dce7ff",
          500: "#4f6ef7",
          600: "#3d5cf5",
          700: "#2d4ae3",
          900: "#1a2d8f",
        },
      },
    },
  },
  plugins: [],
};
EOF
log "tailwind.config.js"

# ── index.css ─────────────────────────────────────────────────────────────────
cat > src/index.css << 'EOF'
@import url('https://fonts.googleapis.com/css2?family=DM+Sans:wght@300;400;500;600&family=JetBrains+Mono:wght@400;500&display=swap');
@tailwind base;
@tailwind components;
@tailwind utilities;

:root {
  --bg-primary:   #0f1117;
  --bg-surface:   #181b25;
  --bg-elevated:  #1f2333;
  --border:       #2a2f45;
  --text-primary: #e8eaf0;
  --text-muted:   #7b82a0;
  --accent:       #4f6ef7;
  --accent-glow:  rgba(79, 110, 247, 0.15);
  --green:        #34d399;
  --amber:        #fbbf24;
  --red:          #f87171;
}

* { box-sizing: border-box; margin: 0; padding: 0; }
body {
  background: var(--bg-primary);
  color: var(--text-primary);
  font-family: 'DM Sans', system-ui, sans-serif;
  font-size: 15px;
  line-height: 1.6;
  -webkit-font-smoothing: antialiased;
}

::-webkit-scrollbar       { width: 6px; height: 6px; }
::-webkit-scrollbar-track { background: transparent; }
::-webkit-scrollbar-thumb { background: var(--border); border-radius: 3px; }

.card {
  background: var(--bg-surface);
  border: 1px solid var(--border);
  border-radius: 12px;
  padding: 20px;
}

.badge {
  display: inline-flex;
  align-items: center;
  padding: 2px 10px;
  border-radius: 20px;
  font-size: 11px;
  font-weight: 500;
  letter-spacing: 0.03em;
  text-transform: uppercase;
}
.badge-important  { background: rgba(79,110,247,.18); color: #818cf8; }
.badge-promotions { background: rgba(251,191,36,.15); color: #fbbf24; }
.badge-spam       { background: rgba(248,113,113,.15); color: #f87171; }
.badge-social     { background: rgba(52,211,153,.15);  color: #34d399; }
.badge-updates    { background: rgba(123,130,160,.15); color: #7b82a0; }
EOF
log "src/index.css"

# ── src/api/client.js ─────────────────────────────────────────────────────────
mkdir -p src/api
cat > src/api/client.js << 'EOF'
/**
 * api/client.js
 * Axios instance configured to talk to the FastAPI backend.
 * Import `api` in hooks/pages — never use fetch() directly.
 */
import axios from "axios";

const BASE_URL = import.meta.env.VITE_API_URL ?? "http://localhost:8000/api/v1";

export const api = axios.create({
  baseURL: BASE_URL,
  withCredentials: true,          // Send cookies for session auth
  headers: { "Content-Type": "application/json" },
});

// Global error interceptor: redirect to login on 401
api.interceptors.response.use(
  (res) => res,
  (err) => {
    if (err.response?.status === 401) {
      window.location.href = "/login";
    }
    return Promise.reject(err);
  }
);

// Convenience methods
export const emailsApi = {
  sync:   (maxResults = 50) => api.post(`/emails/sync?max_results=${maxResults}`),
  list:   (page = 1, label = null) =>
    api.get("/emails", { params: { page, page_size: 20, ...(label && { label }) } }),
  delete: (id) => api.delete(`/emails/${id}`),
};

export const behaviorApi = {
  log:         (emailId, action) => api.post("/behavior/log", { email_id: emailId, action }),
  suggestions: ()                => api.get("/behavior/suggestions"),
};

export const insightsApi = {
  summary: () => api.get("/insights/summary"),
};

export const authApi = {
  status: ()  => api.get("/auth/status"),
  logout: ()  => api.post("/auth/logout"),
  loginUrl: () => `${BASE_URL}/auth/login`,
};
EOF
log "src/api/client.js"

# ── src/store/emailStore.js ───────────────────────────────────────────────────
mkdir -p src/store
cat > src/store/emailStore.js << 'EOF'
/**
 * store/emailStore.js
 * Zustand global store — single source of truth for the frontend.
 * Components read from this store; they don't each manage their own fetch state.
 */
import { create } from "zustand";

export const useEmailStore = create((set, get) => ({
  // Auth
  isAuthenticated: false,
  setAuthenticated: (val) => set({ isAuthenticated: val }),

  // Emails
  emails: [],
  totalEmails: 0,
  activeLabel: null,
  setEmails: (emails, total) => set({ emails, totalEmails: total }),
  setActiveLabel: (label) => set({ activeLabel: label }),

  // Insights
  insights: null,
  setInsights: (data) => set({ insights: data }),

  // UI state
  isSyncing: false,
  setSyncing: (val) => set({ isSyncing: val }),

  // Optimistic delete — remove from UI immediately
  removeEmail: (id) =>
    set((state) => ({ emails: state.emails.filter((e) => e.id !== id) })),
}));
EOF
log "src/store/emailStore.js"

# ── src/hooks/useEmails.js ────────────────────────────────────────────────────
mkdir -p src/hooks
cat > src/hooks/useEmails.js << 'EOF'
import { useEffect } from "react";
import { emailsApi, behaviorApi } from "../api/client";
import { useEmailStore } from "../store/emailStore";

export function useEmails(label = null) {
  const { setEmails, setSyncing, removeEmail } = useEmailStore();

  const fetchEmails = async (page = 1) => {
    const res = await emailsApi.list(page, label);
    setEmails(res.data.emails, res.data.total);
  };

  const syncEmails = async () => {
    setSyncing(true);
    try {
      await emailsApi.sync(50);
      await fetchEmails();
    } finally {
      setSyncing(false);
    }
  };

  const deleteEmail = async (id) => {
    removeEmail(id);   // Optimistic update first
    await emailsApi.delete(id);
    await behaviorApi.log(id, "delete");
  };

  const logOpen = (id) => behaviorApi.log(id, "open");

  useEffect(() => { fetchEmails(); }, [label]);

  return { fetchEmails, syncEmails, deleteEmail, logOpen };
}
EOF
log "src/hooks/useEmails.js"

cat > src/hooks/useInsights.js << 'EOF'
import { useEffect } from "react";
import { insightsApi } from "../api/client";
import { useEmailStore } from "../store/emailStore";

export function useInsights() {
  const setInsights = useEmailStore((s) => s.setInsights);

  useEffect(() => {
    insightsApi.summary().then((res) => setInsights(res.data));
  }, []);
}
EOF
log "src/hooks/useInsights.js"

# ── src/components/layout ────────────────────────────────────────────────────
mkdir -p src/components/layout src/components/emails src/components/dashboard

cat > src/components/layout/Sidebar.jsx << 'EOF'
import { NavLink } from "react-router-dom";
import { LayoutDashboard, Mail, BarChart2, Lightbulb, Settings } from "lucide-react";
import { useEmailStore } from "../../store/emailStore";

const NAV = [
  { to: "/dashboard",  icon: LayoutDashboard, label: "Dashboard" },
  { to: "/emails",     icon: Mail,            label: "Inbox"     },
  { to: "/insights",   icon: BarChart2,       label: "Insights"  },
];

const LABELS = ["important", "promotions", "spam", "social", "updates"];

export default function Sidebar() {
  const setActiveLabel = useEmailStore((s) => s.setActiveLabel);
  const activeLabel    = useEmailStore((s) => s.activeLabel);

  return (
    <aside style={{
      width: 220, minHeight: "100vh",
      background: "var(--bg-surface)",
      borderRight: "1px solid var(--border)",
      display: "flex", flexDirection: "column", padding: "24px 0",
    }}>
      {/* Logo */}
      <div style={{ padding: "0 20px 28px", display: "flex", alignItems: "center", gap: 10 }}>
        <div style={{
          width: 32, height: 32, borderRadius: 8,
          background: "var(--accent)", display: "grid", placeItems: "center",
        }}>
          <Mail size={16} color="#fff" />
        </div>
        <span style={{ fontWeight: 600, fontSize: 15 }}>MailMind</span>
      </div>

      {/* Main nav */}
      <nav style={{ flex: 1 }}>
        {NAV.map(({ to, icon: Icon, label }) => (
          <NavLink key={to} to={to} style={({ isActive }) => ({
            display: "flex", alignItems: "center", gap: 10,
            padding: "9px 20px", fontSize: 14, fontWeight: 500,
            color: isActive ? "var(--accent)" : "var(--text-muted)",
            background: isActive ? "var(--accent-glow)" : "transparent",
            textDecoration: "none", borderRight: isActive ? "2px solid var(--accent)" : "2px solid transparent",
            transition: "all .15s",
          })}>
            <Icon size={16} />
            {label}
          </NavLink>
        ))}

        {/* Label filters */}
        <div style={{ margin: "20px 20px 8px", fontSize: 11, fontWeight: 600, color: "var(--text-muted)", letterSpacing: ".08em", textTransform: "uppercase" }}>
          Labels
        </div>
        {LABELS.map((l) => (
          <button key={l} onClick={() => setActiveLabel(activeLabel === l ? null : l)}
            style={{
              display: "block", width: "100%", textAlign: "left",
              padding: "7px 20px", fontSize: 13,
              color: activeLabel === l ? "var(--text-primary)" : "var(--text-muted)",
              background: activeLabel === l ? "var(--accent-glow)" : "transparent",
              border: "none", cursor: "pointer", transition: "all .15s",
            }}>
            <span className={`badge badge-${l}`}>{l}</span>
          </button>
        ))}
      </nav>
    </aside>
  );
}
EOF

cat > src/components/layout/Header.jsx << 'EOF'
import { RefreshCw, LogOut } from "lucide-react";
import { useEmails } from "../../hooks/useEmails";
import { useEmailStore } from "../../store/emailStore";
import { authApi } from "../../api/client";

export default function Header({ title }) {
  const { syncEmails } = useEmails();
  const isSyncing = useEmailStore((s) => s.isSyncing);

  return (
    <header style={{
      height: 56, borderBottom: "1px solid var(--border)",
      display: "flex", alignItems: "center", justifyContent: "space-between",
      padding: "0 28px", background: "var(--bg-surface)",
    }}>
      <h1 style={{ fontSize: 16, fontWeight: 600 }}>{title}</h1>
      <div style={{ display: "flex", gap: 10 }}>
        <button onClick={syncEmails} disabled={isSyncing} style={{
          display: "flex", alignItems: "center", gap: 6, padding: "6px 14px",
          background: "var(--accent)", color: "#fff", border: "none",
          borderRadius: 8, fontSize: 13, fontWeight: 500, cursor: "pointer",
          opacity: isSyncing ? 0.6 : 1,
        }}>
          <RefreshCw size={13} style={{ animation: isSyncing ? "spin 1s linear infinite" : "none" }} />
          {isSyncing ? "Syncing…" : "Sync"}
        </button>
        <button onClick={() => { authApi.logout(); window.location.href = "/login"; }}
          style={{ display: "flex", alignItems: "center", gap: 6, padding: "6px 12px",
            background: "transparent", color: "var(--text-muted)", border: "1px solid var(--border)",
            borderRadius: 8, fontSize: 13, cursor: "pointer" }}>
          <LogOut size={13} /> Sign out
        </button>
      </div>
      <style>{`@keyframes spin { to { transform: rotate(360deg) }}`}</style>
    </header>
  );
}
EOF
log "layout components"

# ── EmailCard ─────────────────────────────────────────────────────────────────
cat > src/components/emails/EmailCard.jsx << 'EOF'
import { Trash2 } from "lucide-react";
import { formatDistanceToNow } from "date-fns";

export default function EmailCard({ email, onDelete, onOpen }) {
  return (
    <div onClick={() => onOpen?.(email.id)} style={{
      display: "flex", alignItems: "flex-start", gap: 14,
      padding: "14px 18px", borderBottom: "1px solid var(--border)",
      cursor: "pointer", transition: "background .1s",
    }}
    onMouseEnter={e => e.currentTarget.style.background = "var(--bg-elevated)"}
    onMouseLeave={e => e.currentTarget.style.background = "transparent"}>

      {/* Unread dot */}
      <div style={{ marginTop: 6, width: 7, height: 7, borderRadius: "50%",
        background: email.is_read ? "transparent" : "var(--accent)", flexShrink: 0 }} />

      {/* Content */}
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 3 }}>
          <span style={{ fontWeight: 500, fontSize: 13, color: "var(--text-primary)", flexShrink: 0 }}>
            {email.sender.split("<")[0].trim() || email.sender_email}
          </span>
          {email.label && <span className={`badge badge-${email.label}`}>{email.label}</span>}
          <span style={{ marginLeft: "auto", fontSize: 11, color: "var(--text-muted)", flexShrink: 0 }}>
            {formatDistanceToNow(new Date(email.timestamp), { addSuffix: true })}
          </span>
        </div>
        <div style={{ fontSize: 13, fontWeight: 500, color: "var(--text-primary)", marginBottom: 2,
          overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
          {email.subject}
        </div>
        <div style={{ fontSize: 12, color: "var(--text-muted)",
          overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
          {email.snippet}
        </div>
      </div>

      {/* Delete button */}
      <button onClick={(e) => { e.stopPropagation(); onDelete?.(email.id); }}
        style={{ padding: 6, background: "transparent", border: "none",
          cursor: "pointer", color: "var(--text-muted)", borderRadius: 6,
          opacity: 0, transition: "opacity .15s" }}
        className="delete-btn">
        <Trash2 size={14} />
      </button>
      <style>{`.delete-btn { opacity: 0 } div:hover .delete-btn { opacity: 1 }`}</style>
    </div>
  );
}
EOF
log "EmailCard.jsx"

# ── StatCard ──────────────────────────────────────────────────────────────────
cat > src/components/dashboard/StatCard.jsx << 'EOF'
export default function StatCard({ label, value, sub, color = "var(--accent)" }) {
  return (
    <div className="card" style={{ display: "flex", flexDirection: "column", gap: 6 }}>
      <span style={{ fontSize: 11, fontWeight: 600, color: "var(--text-muted)",
        textTransform: "uppercase", letterSpacing: ".08em" }}>{label}</span>
      <span style={{ fontSize: 32, fontWeight: 600, color }}>{value ?? "—"}</span>
      {sub && <span style={{ fontSize: 12, color: "var(--text-muted)" }}>{sub}</span>}
    </div>
  );
}
EOF
log "StatCard.jsx"

# ── Pages ─────────────────────────────────────────────────────────────────────
mkdir -p src/pages

cat > src/pages/LoginPage.jsx << 'EOF'
import { Mail, Sparkles } from "lucide-react";
import { authApi } from "../api/client";

export default function LoginPage() {
  return (
    <div style={{ minHeight: "100vh", display: "grid", placeItems: "center",
      background: "var(--bg-primary)" }}>
      <div style={{ textAlign: "center", maxWidth: 400 }}>
        <div style={{ width: 64, height: 64, borderRadius: 16, background: "var(--accent)",
          display: "grid", placeItems: "center", margin: "0 auto 24px" }}>
          <Mail size={28} color="#fff" />
        </div>
        <h1 style={{ fontSize: 28, fontWeight: 600, marginBottom: 10 }}>MailMind</h1>
        <p style={{ color: "var(--text-muted)", marginBottom: 32, lineHeight: 1.7 }}>
          AI-powered email assistant that learns your habits and keeps your inbox under control.
        </p>
        <a href={authApi.loginUrl()} style={{
          display: "inline-flex", alignItems: "center", gap: 10,
          padding: "12px 28px", background: "var(--accent)", color: "#fff",
          borderRadius: 10, fontWeight: 500, fontSize: 15, textDecoration: "none",
          transition: "opacity .15s",
        }}
        onMouseEnter={e => e.currentTarget.style.opacity = ".85"}
        onMouseLeave={e => e.currentTarget.style.opacity = "1"}>
          <Sparkles size={16} /> Connect Gmail
        </a>
        <p style={{ fontSize: 12, color: "var(--text-muted)", marginTop: 20 }}>
          We only read email metadata — we never store full email bodies.
        </p>
      </div>
    </div>
  );
}
EOF

cat > src/pages/DashboardPage.jsx << 'EOF'
import { PieChart, Pie, Cell, Tooltip, ResponsiveContainer, BarChart, Bar, XAxis, YAxis } from "recharts";
import { useInsights } from "../hooks/useInsights";
import { useEmailStore } from "../store/emailStore";
import StatCard from "../components/dashboard/StatCard";
import Header from "../components/layout/Header";

const COLORS = { important: "#4f6ef7", promotions: "#fbbf24", spam: "#f87171", social: "#34d399", updates: "#7b82a0" };

export default function DashboardPage() {
  useInsights();
  const insights = useEmailStore((s) => s.insights);

  const pieData = insights ? [
    { name: "Important",  value: insights.important },
    { name: "Promotions", value: insights.promotions },
    { name: "Spam",       value: insights.spam },
    { name: "Social",     value: insights.social },
    { name: "Updates",    value: insights.updates },
  ].filter(d => d.value > 0) : [];

  return (
    <div style={{ flex: 1, overflow: "auto" }}>
      <Header title="Dashboard" />
      <div style={{ padding: 28 }}>
        {/* Stats row */}
        <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 16, marginBottom: 28 }}>
          <StatCard label="Total emails" value={insights?.total_emails} />
          <StatCard label="Unread" value={insights?.unread} color="var(--amber)" />
          <StatCard label="Spam / Promos" value={(insights?.spam ?? 0) + (insights?.promotions ?? 0)} color="var(--red)" />
          <StatCard label="Weekly change" value={`${insights?.week_over_week_change ?? 0}%`} color="var(--green)"
            sub={insights?.week_over_week_change >= 0 ? "↑ more than last week" : "↓ less than last week"} />
        </div>

        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 16, marginBottom: 28 }}>
          {/* Pie chart */}
          <div className="card">
            <h2 style={{ fontSize: 13, fontWeight: 600, marginBottom: 16, color: "var(--text-muted)" }}>BY CATEGORY</h2>
            <ResponsiveContainer width="100%" height={220}>
              <PieChart>
                <Pie data={pieData} cx="50%" cy="50%" innerRadius={60} outerRadius={90} paddingAngle={3} dataKey="value">
                  {pieData.map((entry) => (
                    <Cell key={entry.name} fill={COLORS[entry.name.toLowerCase()] ?? "#888"} />
                  ))}
                </Pie>
                <Tooltip contentStyle={{ background: "var(--bg-elevated)", border: "1px solid var(--border)", borderRadius: 8, fontSize: 12 }} />
              </PieChart>
            </ResponsiveContainer>
            <div style={{ display: "flex", flexWrap: "wrap", gap: 8, marginTop: 8 }}>
              {pieData.map(d => (
                <span key={d.name} style={{ display: "flex", alignItems: "center", gap: 5, fontSize: 12, color: "var(--text-muted)" }}>
                  <span style={{ width: 8, height: 8, borderRadius: "50%", background: COLORS[d.name.toLowerCase()] }} />
                  {d.name} ({d.value})
                </span>
              ))}
            </div>
          </div>

          {/* Suggestions */}
          <div className="card">
            <h2 style={{ fontSize: 13, fontWeight: 600, marginBottom: 16, color: "var(--text-muted)" }}>SUGGESTIONS</h2>
            {(insights?.suggestions ?? []).length === 0 ? (
              <p style={{ color: "var(--text-muted)", fontSize: 13 }}>No suggestions yet — keep using the app to build your behavior profile.</p>
            ) : (
              (insights?.suggestions ?? []).map((s, i) => (
                <div key={i} style={{ padding: "10px 0", borderBottom: "1px solid var(--border)", fontSize: 13 }}>
                  <div style={{ fontWeight: 500, marginBottom: 3 }}>{s.display_name}</div>
                  <div style={{ color: "var(--text-muted)", fontSize: 12 }}>{s.suggestion}</div>
                </div>
              ))
            )}
          </div>
        </div>

        {/* Top senders */}
        <div className="card">
          <h2 style={{ fontSize: 13, fontWeight: 600, marginBottom: 16, color: "var(--text-muted)" }}>TOP SENDERS</h2>
          <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13 }}>
            <thead>
              <tr style={{ color: "var(--text-muted)", fontSize: 11, textTransform: "uppercase", letterSpacing: ".06em" }}>
                <th style={{ textAlign: "left", padding: "4px 0", fontWeight: 600 }}>Sender</th>
                <th style={{ textAlign: "right", padding: "4px 0", fontWeight: 600 }}>Received</th>
                <th style={{ textAlign: "right", padding: "4px 0", fontWeight: 600 }}>Open rate</th>
                <th style={{ textAlign: "right", padding: "4px 0", fontWeight: 600 }}>Score</th>
              </tr>
            </thead>
            <tbody>
              {(insights?.top_senders ?? []).map((s) => (
                <tr key={s.sender_email} style={{ borderTop: "1px solid var(--border)" }}>
                  <td style={{ padding: "9px 0" }}>
                    <div style={{ fontWeight: 500 }}>{s.display_name}</div>
                    <div style={{ fontSize: 11, color: "var(--text-muted)" }}>{s.sender_email}</div>
                  </td>
                  <td style={{ textAlign: "right", color: "var(--text-muted)" }}>{s.total_received}</td>
                  <td style={{ textAlign: "right", color: "var(--text-muted)" }}>{(s.open_rate * 100).toFixed(0)}%</td>
                  <td style={{ textAlign: "right" }}>
                    <span style={{ color: s.importance_score >= 0 ? "var(--green)" : "var(--red)", fontWeight: 500 }}>
                      {s.importance_score >= 0 ? "+" : ""}{s.importance_score}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
EOF

cat > src/pages/EmailsPage.jsx << 'EOF'
import Header from "../components/layout/Header";
import EmailCard from "../components/emails/EmailCard";
import { useEmails } from "../hooks/useEmails";
import { useEmailStore } from "../store/emailStore";

export default function EmailsPage() {
  const activeLabel = useEmailStore((s) => s.activeLabel);
  const emails      = useEmailStore((s) => s.emails);
  const total       = useEmailStore((s) => s.totalEmails);
  const { deleteEmail, logOpen } = useEmails(activeLabel);

  return (
    <div style={{ flex: 1, overflow: "auto" }}>
      <Header title={activeLabel ? `Label: ${activeLabel}` : "Inbox"} />
      <div style={{ padding: "0 0 40px" }}>
        <div style={{ padding: "12px 18px", fontSize: 12, color: "var(--text-muted)", borderBottom: "1px solid var(--border)" }}>
          {total} emails {activeLabel && `· filtered by ${activeLabel}`}
        </div>
        {emails.length === 0 ? (
          <div style={{ padding: 40, textAlign: "center", color: "var(--text-muted)" }}>
            No emails found. Hit Sync to fetch your inbox.
          </div>
        ) : (
          emails.map((email) => (
            <EmailCard key={email.id} email={email}
              onDelete={deleteEmail}
              onOpen={(id) => logOpen(id)} />
          ))
        )}
      </div>
    </div>
  );
}
EOF

cat > src/pages/InsightsPage.jsx << 'EOF'
import Header from "../components/layout/Header";

export default function InsightsPage() {
  return (
    <div style={{ flex: 1 }}>
      <Header title="Insights" />
      <div style={{ padding: 28, color: "var(--text-muted)", fontSize: 14 }}>
        Weekly insights coming in Phase 3 — sync more emails to build your behavior profile.
      </div>
    </div>
  );
}
EOF
log "pages"

# ── App.jsx ───────────────────────────────────────────────────────────────────
cat > src/App.jsx << 'EOF'
import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import { useEffect } from "react";
import { authApi } from "./api/client";
import { useEmailStore } from "./store/emailStore";
import Sidebar from "./components/layout/Sidebar";
import LoginPage from "./pages/LoginPage";
import DashboardPage from "./pages/DashboardPage";
import EmailsPage from "./pages/EmailsPage";
import InsightsPage from "./pages/InsightsPage";

function AppLayout({ children }) {
  return (
    <div style={{ display: "flex", minHeight: "100vh" }}>
      <Sidebar />
      <div style={{ flex: 1, display: "flex", flexDirection: "column" }}>
        {children}
      </div>
    </div>
  );
}

function ProtectedRoute({ children }) {
  const isAuthenticated = useEmailStore((s) => s.isAuthenticated);
  return isAuthenticated ? children : <Navigate to="/login" replace />;
}

export default function App() {
  const { setAuthenticated } = useEmailStore();

  useEffect(() => {
    authApi.status()
      .then((res) => setAuthenticated(res.data.authenticated))
      .catch(() => setAuthenticated(false));
  }, []);

  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route path="/dashboard" element={<ProtectedRoute><AppLayout><DashboardPage /></AppLayout></ProtectedRoute>} />
        <Route path="/emails"    element={<ProtectedRoute><AppLayout><EmailsPage /></AppLayout></ProtectedRoute>} />
        <Route path="/insights"  element={<ProtectedRoute><AppLayout><InsightsPage /></AppLayout></ProtectedRoute>} />
        <Route path="*" element={<Navigate to="/dashboard" replace />} />
      </Routes>
    </BrowserRouter>
  );
}
EOF
log "App.jsx"

# ── main.jsx ──────────────────────────────────────────────────────────────────
cat > src/main.jsx << 'EOF'
import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App";
import "./index.css";

ReactDOM.createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
EOF

# ── .env ──────────────────────────────────────────────────────────────────────
cat > .env << 'EOF'
VITE_API_URL=http://localhost:8000/api/v1
EOF
log ".env"

cd ..   # Back to project root

# =============================================================================
#  DOCS
# =============================================================================
head "Writing documentation"
mkdir -p docs

cat > docs/gmail_setup.md << 'EOF'
# Gmail API Setup — Step by Step

## 1. Create a Google Cloud Project
1. Go to https://console.cloud.google.com
2. Click "New Project" → name it "email-assistant"
3. Click "Create"

## 2. Enable the Gmail API
1. Go to APIs & Services → Library
2. Search "Gmail API" → click Enable

## 3. Configure OAuth Consent Screen
1. APIs & Services → OAuth consent screen
2. User Type: External → Create
3. Fill in App name, support email, developer email
4. Scopes: add `gmail.readonly`, `gmail.modify`
5. Test users: add your own Gmail address

## 4. Create OAuth Credentials
1. APIs & Services → Credentials → Create Credentials → OAuth client ID
2. Application type: Web application
3. Authorized redirect URIs: `http://localhost:8000/api/v1/auth/callback`
4. Download the JSON → copy client_id and client_secret

## 5. Update backend/.env
```
GOOGLE_CLIENT_ID=<paste here>
GOOGLE_CLIENT_SECRET=<paste here>
```

## 6. First Run Flow
1. Start backend: `cd backend && python run.py`
2. Visit: http://localhost:8000/api/v1/auth/login
3. Approve Google consent screen
4. You'll be redirected to the React app
5. Hit "Sync" to fetch your first emails
EOF

cat > README.md << 'EOF'
# AI-Powered Personal Email Assistant

## Quick Start

```bash
# 1. Fill in your Google credentials
nano backend/.env

# 2. Start backend (in one terminal)
cd backend
source venv/bin/activate
python run.py

# 3. Start frontend (in another terminal)
cd frontend
npm run dev
```

Then visit: http://localhost:5173

## API Docs
Auto-generated Swagger UI: http://localhost:8000/docs

## Phases
- Phase 1 ✅ Gmail OAuth + fetch + rule-based classification
- Phase 2 ✅ Behavior tracking + sender scoring
- Phase 3 ✅ Dashboard + suggestions

## Deployment
See docs/gmail_setup.md for full setup instructions.
EOF
log "Documentation written"


# =============================================================================
#  PYTHON VIRTUAL ENV + INSTALL
# =============================================================================
head "Setting up Python virtual environment"

cd backend
python3 -m venv venv
source venv/bin/activate
pip install --quiet --upgrade pip
pip install --quiet -r requirements.txt
log "Python dependencies installed"
deactivate
cd ..

mkdir -p backend/tokens
echo "tokens/" >> .gitignore
echo "__pycache__/" >> .gitignore
echo "*.pyc" >> .gitignore
echo ".env" >> .gitignore
echo "*.db" >> .gitignore
echo "node_modules/" >> .gitignore
echo ".DS_Store" >> .gitignore

# =============================================================================
#  DONE
# =============================================================================
echo ""
echo -e "${BOLD}${GREEN}╔═══════════════════════════════════════════════════╗"
echo -e "║   Setup complete! Here's what to do next:         ║"
echo -e "╚═══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Step 1${NC} — Add your Google credentials:"
echo -e "       ${YELLOW}nano email-assistant/backend/.env${NC}"
echo ""
echo -e "${CYAN}Step 2${NC} — Start the backend:"
echo -e "       ${YELLOW}cd email-assistant/backend"
echo -e "       source venv/bin/activate"
echo -e "       python run.py${NC}"
echo ""
echo -e "${CYAN}Step 3${NC} — Start the frontend (new terminal):"
echo -e "       ${YELLOW}cd email-assistant/frontend"
echo -e "       npm run dev${NC}"
echo ""
echo -e "${CYAN}Step 4${NC} — Authenticate:"
echo -e "       Open ${YELLOW}http://localhost:8000/api/v1/auth/login${NC}"
echo ""
echo -e "${CYAN}API Docs${NC} → ${YELLOW}http://localhost:8000/docs${NC}"
echo -e "${CYAN}App${NC}      → ${YELLOW}http://localhost:5173${NC}"
echo ""
echo -e "Full setup guide: ${YELLOW}email-assistant/docs/gmail_setup.md${NC}"
echo ""