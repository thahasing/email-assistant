"""Entry point for running the backend server."""

import os

import uvicorn


if __name__ == "__main__":
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8003,
        reload=os.getenv("UVICORN_RELOAD", "").lower() in {"1", "true", "yes"},
    )
