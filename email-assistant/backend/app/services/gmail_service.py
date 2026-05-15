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
