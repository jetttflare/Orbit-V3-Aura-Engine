#!/bin/bash
echo "📄 AI Resume Optimizer - Starting..."
cd "$(dirname "$0")"
[ ! -d "venv" ] && python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt --quiet
echo "🚀 http://localhost:5011"
python app.py
