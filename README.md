# AI-Powered Personal Email Assistant

Lightweight app that connects to Gmail, fetches messages, applies simple
classifiers and shows insights in a React dashboard.

## Features
- Google OAuth 2.0 sign-in (Gmail API)
- Fetch & store messages (SQLite)
- Rule-based classification and sender scoring
- React + Vite frontend dashboard

## Prerequisites
- Python 3.12 (recommended) and virtualenv
- Node 18+ and npm
- A Google Cloud project with Gmail API enabled and OAuth credentials

## Setup (local development)

1. Backend: create and activate a virtual environment

```bash
cd backend
python -m venv ../venv_py312   # or use your preferred venv
source ../venv_py312/bin/activate
pip install -r requirements.txt
```

2. Copy and populate environment variables

Create `backend/.env` (example keys below):

```env
GOOGLE_CLIENT_ID=<your-client-id>
GOOGLE_CLIENT_SECRET=<your-client-secret>
GOOGLE_REDIRECT_URI=http://localhost:8000/api/v1/auth/callback
SECRET_KEY=changeme
FRONTEND_URL=http://127.0.0.1:5173
DATABASE_URL=sqlite:///./email_assistant.db
ENVIRONMENT=development
```

Important: the `GOOGLE_REDIRECT_URI` you register in Google Cloud MUST exactly
match the value above (including scheme, host, port and path).

3. Start the backend

```bash
cd backend
../../venv_py312/bin/python run.py   # or use your active venv python
```

The API will be available at `http://127.0.0.1:8000` and OpenAPI at
`http://127.0.0.1:8000/docs`.

4. Frontend

```bash
cd frontend
npm install
npm run dev
```

Open the app at `http://127.0.0.1:5173`.

## Google OAuth quick notes
1. In the Google Cloud Console, enable Gmail API and create OAuth credentials
	 (Application type: Web application).
2. Add an authorized redirect URI exactly matching
	 `http://localhost:8000/api/v1/auth/callback` (or your configured backend URL).
3. Add your `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` to `backend/.env`.

## Tests

Run backend unit tests (from project root):

```bash
cd backend
../../venv_py312/bin/python -m pytest
```

## Pushing to GitHub
This project is ready for Git. See the repo remote already configured in
this workspace. Don't commit secrets — keep `.env` out of the repository.

## Troubleshooting
- If you see `redirect_uri_mismatch`, verify the redirect URI in Google
	Cloud matches `GOOGLE_REDIRECT_URI` in `backend/.env`.
- If port 8000 is in use, either stop the occupying process or run the
	backend on a different port (edit `run.py`).

## Docs
See `docs/gmail_setup.md` for a step-by-step guide to creating OAuth
credentials in Google Cloud.

If you want, I can add CI, a LICENSE file, or improve the README badges.
