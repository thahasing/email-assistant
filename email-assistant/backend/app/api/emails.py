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
from app.services.behavior_tracker import log_action
from app.models.email import Email
from app.models.classification import Classification
from app.schemas.email import EmailListResponse, EmailResponse
from datetime import datetime, timedelta
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
            thread_id=email.thread_id,
            subject=email.subject,
            sender=email.sender,
            sender_email=email.sender_email,
            snippet=email.snippet,
            timestamp=email.timestamp,
            is_read=email.is_read,
            is_deleted=email.is_deleted,
            labels=email.labels,
            created_at=email.created_at,
            updated_at=email.updated_at,
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


@router.post("/auto-cleanup")
def auto_cleanup_unopened(
    days_old: int = Query(7, ge=1, le=90, description="Delete unopened emails older than X days"),
    dry_run: bool = Query(False, description="If true, only show what would be deleted"),
    db: Session = Depends(get_db),
):
    """
    Auto-detect and delete unopened emails older than X days.
    
    This helps keep your inbox clean by removing emails you never read.
    
    Args:
        days_old: Delete unopened emails older than this many days (default 7)
        dry_run:  If True, only show what would be deleted, don't actually delete
    
    Returns:
        List of emails that were (or would be) deleted
    """
    cutoff_date = datetime.utcnow() - timedelta(days=days_old)
    
    # Find unopened emails older than cutoff
    unopened_old = (
        db.query(Email)
        .filter(
            Email.is_read == False,
            Email.is_deleted == False,
            Email.timestamp < cutoff_date,
        )
        .all()
    )
    
    deleted_emails = []
    
    for email in unopened_old:
        deleted_emails.append({
            "id": email.id,
            "subject": email.subject,
            "sender": email.sender,
            "timestamp": email.timestamp,
        })
        
        if not dry_run:
            # Delete in Gmail
            success = gmail_service.trash_email(email.id)
            if success:
                # Mark as deleted in DB
                email.is_deleted = True
                
                # Log the auto-delete behavior
                try:
                    log_action(email.id, "auto_delete", db=db)
                except Exception as e:
                    print(f"Warning: Could not log behavior: {e}")
    
    if not dry_run:
        db.commit()
    
    return {
        "dry_run": dry_run,
        "deleted_count": len(deleted_emails),
        "emails": deleted_emails,
        "message": f"{'Would delete' if dry_run else 'Deleted'} {len(deleted_emails)} unopened emails older than {days_old} days"
    }
