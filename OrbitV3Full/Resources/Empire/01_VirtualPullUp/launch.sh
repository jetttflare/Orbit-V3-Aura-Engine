#!/bin/bash
# Virtual Pull-Up AI - Launch Script

echo "🎙️ Virtual Pull-Up AI - Starting..."

# Navigate to script directory
cd "$(dirname "$0")"

# Check for virtual environment
if [ ! -d "venv" ]; then
    echo "📦 Creating virtual environment..."
    python3 -m venv venv
fi

# Activate venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt --quiet

# Create .env if not exists
if [ ! -f ".env" ]; then
    echo "📝 Creating .env template..."
    cat > .env << EOF
GEMINI_API_KEY=
GROK_API_KEY=
ELEVENLABS_API_KEY=
SUPABASE_URL=
SUPABASE_KEY=
STRIPE_SECRET_KEY=
EOF
    echo "⚠️  Please configure .env with your API keys"
fi

# Run the app
echo "🚀 Starting server on http://localhost:5001"
python app.py
