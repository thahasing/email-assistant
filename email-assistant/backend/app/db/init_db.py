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
