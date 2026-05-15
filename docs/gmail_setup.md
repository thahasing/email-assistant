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
