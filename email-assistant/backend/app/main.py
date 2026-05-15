"""
main.py
=======
FastAPI application entry point.
Registers all routers, configures CORS, and initialises the database on startup.

To run:  uvicorn app.main:app --reload  (from the backend/ directory)
Docs at: http://localhost:8003/docs
"""

from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
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
    allow_origins=[settings.frontend_url, "http://localhost:5173", "http://localhost:5174", "http://localhost:5175"],
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

# ── Static files (React build) ──────────────────────────────────────────────
FRONTEND_DIST_DIR = Path(__file__).resolve().parents[2] / "frontend" / "dist"

if FRONTEND_DIST_DIR.exists():
    app.mount("/static", StaticFiles(directory=str(FRONTEND_DIST_DIR)), name="static")


# ── Startup ───────────────────────────────────────────────────────────────────
@app.on_event("startup")
def on_startup():
    """Create DB tables when the server starts (idempotent)."""
    init_db()


@app.get("/")
def root():
    """Root endpoint for quick status check."""
    return {
        "message": "AI Email Assistant API is running",
        "health": "/health",
        "api_base": "/api/v1",
        "frontend": "/static/index.html" if FRONTEND_DIST_DIR.exists() else settings.frontend_url,
        "info": "Use /api/v1/auth/status or /api/v1/insights/summary etc.",
    }


@app.exception_handler(404)
def custom_404(request, exc):
    return JSONResponse(
        status_code=404,
        content={
            "detail": "Route not found. Please use /api/v1/<endpoint> or /health. If you meant frontend, run npm run dev in frontend and visit http://localhost:5173.",
        },
    )


@app.get("/health")
def health_check():
    """Simple health check — used by load balancers and Docker healthchecks."""
    return {"status": "ok", "version": "1.0.0"}
