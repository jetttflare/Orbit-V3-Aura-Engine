#!/bin/bash
# Lil Bit Podcast Factory - Launch Script
echo "🎧 Lil Bit Podcast Factory - Starting..."
cd "$(dirname "$0")"
[ ! -d "venv" ] && python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt --quiet
[ ! -f ".env" ] && cat > .env << EOF
GEMINI_API_KEY=
ELEVENLABS_API_KEY=
SUPABASE_URL=
SUPABASE_KEY=
STRIPE_SECRET_KEY=
EOF
echo "🚀 Starting server on http://localhost:5002"
python app.py
