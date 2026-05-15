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
Auto-generated Swagger UI: http://localhost:8003/docs

## Phases
- Phase 1 ✅ Gmail OAuth + fetch + rule-based classification
- Phase 2 ✅ Behavior tracking + sender scoring
- Phase 3 ✅ Dashboard + suggestions

## Deployment
See docs/gmail_setup.md for full setup instructions.
