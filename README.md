# Clara

Voice-powered restaurant concierge that helps users discover restaurants and connects them directly via call transfer.

**[Video Walkthrough](https://www.loom.com/share/cdf2eb3f04c74806a26ce17baed08442)**

## Features

- **Voice Interaction**: Natural conversation via WebRTC (browser) or phone (SIP)
- **Restaurant Search**: Find restaurants by location and cuisine using Foursquare
- **Call Transfer**: Connect users directly to restaurants via Twilio SIP
- **Real-time Transcript**: Live captions synced with audio
- **Animated UI**: 3D orb visualization that responds to voice activity

## Architecture

```
┌─────────────────┐     ┌─────────────────┐
│   Web Browser   │     │   Phone Call    │
│    (WebRTC)     │     │     (SIP)       │
└────────┬────────┘     └────────┬────────┘
         │                       │
         └───────────┬───────────┘
                     ▼
            ┌─────────────────┐
            │  LiveKit Cloud  │
            └────────┬────────┘
                     ▼
            ┌─────────────────┐
            │   AWS EC2       │
            │  Clara Agent    │
            │                 │
            │  STT: Deepgram  │
            │  LLM: GPT-4.1   │
            │  TTS: Cartesia  │
            └────────┬────────┘
                     ▼
            ┌─────────────────┐
            │  Foursquare API │
            └─────────────────┘
```

## Tech Stack

| Layer | Technology |
|-------|------------|
| Frontend | Next.js, React Three Fiber, TypeScript |
| Frontend Hosting | Vercel |
| Voice Server | LiveKit Cloud |
| Agent Runtime | Python 3.13, LiveKit Agents SDK |
| STT | Deepgram Nova 3 |
| LLM | OpenAI GPT-4.1 |
| TTS | Cartesia Sonic 3 |
| VAD | Silero |
| Restaurant Data | Foursquare Places API |
| Telephony | Twilio SIP Trunk |
| Backend Hosting | AWS EC2 |
| IaC | Terraform |
| Observability | CloudWatch |

## Quick Start

### Prerequisites

- Python 3.13+
- Node.js 20+
- Docker
- AWS CLI configured
- LiveKit CLI (`brew install livekit-cli`)

### Local Development

**Backend:**

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt -r requirements-dev.txt

# Create .env with your API keys
cp .env.example .env

# Run agent
python main.py dev
```

**Frontend:**

```bash
cd frontend
npm install

# Create .env.local with your API keys
cp .env.example .env.local

# Run dev server
npm run dev
```

Open http://localhost:3000

## Environment Variables

### Backend (.env)

```bash
# LiveKit
LIVEKIT_URL=wss://your-project.livekit.cloud
LIVEKIT_API_KEY=
LIVEKIT_API_SECRET=
LIVEKIT_OUTBOUND_TRUNK_ID=

# Voice Pipeline
DEEPGRAM_API_KEY=
OPENAI_API_KEY=
CARTESIA_API_KEY=

# Foursquare
FOURSQUARE_API_KEY=

# Twilio (for phone calls)
TWILIO_ACCOUNT_SID=
TWILIO_AUTH_TOKEN=
TWILIO_PHONE_NUMBER=

# Call Redirect (dev mode)
CALL_REDIRECT_ENABLED=true
CALL_REDIRECT_NUMBER=
```

### Frontend (.env.local)

```bash
LIVEKIT_URL=wss://your-project.livekit.cloud
LIVEKIT_API_KEY=
LIVEKIT_API_SECRET=
```

## Deployment

### Frontend (Vercel)

```bash
cd frontend
vercel deploy --prod
```

### Backend (AWS)

**1. Store secrets in AWS Parameter Store:**

```bash
./scripts/setup-secrets.sh
```

**2. Deploy infrastructure with Terraform:**

```bash
cd infra
terraform init
terraform apply
```

**3. Build and push Docker image:**

```bash
./scripts/deploy.sh
```

### CI/CD

On push to `main`:
- Backend auto-deploys to EC2 via GitHub Actions
- Frontend auto-deploys to Vercel

Required GitHub Secrets:

| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | AWS access key |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key |
| `ECR_URL` | ECR repository URL |
| `EC2_INSTANCE_ID` | EC2 instance ID |
| `VERCEL_TOKEN` | Vercel API token |
| `VERCEL_ORG_ID` | Vercel org ID |
| `VERCEL_PROJECT_ID` | Vercel project ID |

## Project Structure

```
clara/
├── frontend/
│   ├── src/
│   │   ├── app/
│   │   │   ├── page.tsx
│   │   │   ├── layout.tsx
│   │   │   └── api/token/route.ts
│   │   └── components/
│   │       ├── Orb.tsx
│   │       ├── Transcript.tsx
│   │       └── Controls.tsx
│   └── package.json
├── backend/
│   ├── clara/
│   │   ├── agent.py
│   │   ├── health.py
│   │   ├── logging.py
│   │   └── tools/
│   │       ├── restaurant.py
│   │       └── call.py
│   ├── main.py
│   ├── Dockerfile
│   ├── requirements.txt
│   └── requirements-dev.txt
├── infra/
│   └── main.tf
├── scripts/
│   ├── deploy.sh
│   └── setup-secrets.sh
└── .github/workflows/
    ├── ci.yml
    └── deploy.yml
```

## API Keys

| Service | Free Tier | Sign Up |
|---------|-----------|---------|
| LiveKit | 50 participants/mo | https://cloud.livekit.io |
| Deepgram | $200 credits | https://console.deepgram.com |
| OpenAI | Pay-per-use | https://platform.openai.com |
| Cartesia | 10k chars/mo | https://cartesia.ai |
| Foursquare | $200/mo credits | https://foursquare.com/developers |
| Twilio | $15 trial credit | https://console.twilio.com |

## Development

### Run Tests

```bash
# Backend
cd backend
source .venv/bin/activate
pytest -v

# Frontend
cd frontend
npm run lint
npm run typecheck
```

### Code Quality

```bash
# Backend
ruff check .
ruff format .
pyright

# Frontend
npm run lint
npm run build
```

## License

MIT
