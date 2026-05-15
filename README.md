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

## GitHub Actions
A CI workflow is included in `.github/workflows/ci.yml`.
On every push or pull request to `main`, it will:
- install and test the backend dependencies
- install and build the frontend with Vite

This helps catch regressions before Railway or Vercel deploy.

## Deployment
### Railway backend
Railway is configured to deploy the backend using `backend/Dockerfile`.
To deploy:
1. Create a new Railway project.
2. Connect the GitHub repo `thahasing/email-assistant`.
3. Set the service root to `backend` and deploy from `main`.
4. Provide these Railway environment variables:
   - `GOOGLE_CLIENT_ID`
   - `GOOGLE_CLIENT_SECRET`
   - `GOOGLE_REDIRECT_URI=http://<your-railway-domain>/api/v1/auth/callback`
   - `SECRET_KEY` (random string)
   - `FRONTEND_URL=https://<your-vercel-domain>`
   - `DATABASE_URL=sqlite:///./email_assistant.db` or PostgreSQL URL

Railway will also auto-deploy on every push to `main` once the project is
connected.

### PostgreSQL on Railway (recommended)
If you want a production-ready backend, use Railway Postgres instead of
SQLite. Set `DATABASE_URL` to the connection string provided by Railway,
for example:

```env
DATABASE_URL=postgresql://user:password@host:5432/database_name
```

The backend already supports SQLAlchemy-compatible database URLs, so no
code changes are required.

### Vercel frontend
Vercel can deploy the `frontend` directory as a static app.
To deploy:
1. Create a new Vercel project from GitHub `thahasing/email-assistant`.
2. Set the root directory to `frontend`.
3. Add Vercel environment variables if needed:
   - `VITE_API_URL=https://<your-railway-domain>/api/v1`
4. Vercel uses `npm install` and `npm run build` automatically.

The frontend will be served from a Vercel domain and will connect to the
Railway backend via `VITE_API_URL`.

## Troubleshooting
- If you see `redirect_uri_mismatch`, verify the redirect URI in Google
  Cloud matches the deployed `GOOGLE_REDIRECT_URI`.
- If port 8000 is in use locally, stop the process or run the backend on a
  different port.
- If the frontend cannot reach the backend, verify `VITE_API_URL` is set to
  the Railway backend URL and `FRONTEND_URL` matches your Vercel app URL.

## Docs
See `docs/gmail_setup.md` for a step-by-step guide to creating OAuth
credentials in Google Cloud.
