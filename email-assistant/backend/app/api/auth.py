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
from fastapi.responses import RedirectResponse, JSONResponse
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
    try:
        flow = _build_flow()
        flow.fetch_token(code=code)
        save_token(flow.credentials)

        # Redirect user back to the React app
        return RedirectResponse(url=f"{settings.frontend_url}/dashboard")
    except Exception as e:
        # Log the error and return a user-friendly error page
        print(f"OAuth callback error: {e}")
        return JSONResponse(
            status_code=500,
            content={"error": "OAuth authentication failed", "details": str(e)}
        )


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
