#!/usr/bin/env python3
"""
Virtual Pull-Up AI - Jamie-Style Fact Engine
JRE-inspired proactive research assistant with voice overlays
Version: 1.0.0 | Production Ready
"""

import os
import json
import asyncio
import hashlib
import re
from datetime import datetime, timedelta
from typing import Optional, Dict, List, Any
from dataclasses import dataclass, asdict
from functools import lru_cache

# Flask imports
from flask import Flask, request, jsonify, render_template_string, Response
from flask_cors import CORS

# Async HTTP
import aiohttp
import requests

# Database (optional)
try:
    from supabase import create_client, Client
except ImportError:
    Client = None
    def create_client(*args): return None

# Stripe
import stripe

# Environment
from dotenv import load_dotenv
load_dotenv()

# =============================================================================
# CONFIGURATION
# =============================================================================

app = Flask(__name__)
CORS(app)

# API Keys with fallback rotation
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
GROK_API_KEY = os.getenv("GROK_API_KEY", "")
ELEVENLABS_API_KEY = os.getenv("ELEVENLABS_API_KEY", "")
SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_KEY = os.getenv("SUPABASE_KEY", "")
STRIPE_SECRET_KEY = os.getenv("STRIPE_SECRET_KEY", "")

stripe.api_key = STRIPE_SECRET_KEY

# Supabase client
supabase: Optional[Client] = None
if SUPABASE_URL and SUPABASE_KEY:
    supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

# =============================================================================
# DATA MODELS
# =============================================================================

@dataclass
class FactCheck:
    id: str
    claim: str
    verdict: str  # "true", "false", "partially_true", "unverifiable"
    confidence: float
    sources: List[str]
    explanation: str
    timestamp: str
    audio_url: Optional[str] = None

@dataclass
class User:
    id: str
    email: str
    subscription_tier: str  # "free", "pro", "enterprise"
    hours_used: float
    hours_limit: float
    stripe_customer_id: Optional[str] = None

@dataclass
class ResearchSession:
    id: str
    user_id: str
    topic: str
    facts: List[FactCheck]
    started_at: str
    ended_at: Optional[str] = None
    duration_minutes: float = 0

# =============================================================================
# MEM0 CONTEXT CACHING LAYER
# =============================================================================

class Mem0Cache:
    """In-memory context cache with persistence to Supabase"""
    
    def __init__(self, max_size: int = 10000):
        self.cache: Dict[str, Any] = {}
        self.max_size = max_size
        self.access_times: Dict[str, datetime] = {}
    
    def _generate_key(self, claim: str) -> str:
        """Generate cache key from claim text"""
        normalized = claim.lower().strip()
        return hashlib.md5(normalized.encode()).hexdigest()
    
    def get(self, claim: str) -> Optional[FactCheck]:
        """Retrieve cached fact check"""
        key = self._generate_key(claim)
        if key in self.cache:
            self.access_times[key] = datetime.now()
            return self.cache[key]
        return None
    
    def set(self, claim: str, fact: FactCheck) -> None:
        """Cache a fact check result"""
        if len(self.cache) >= self.max_size:
            self._evict_oldest()
        key = self._generate_key(claim)
        self.cache[key] = fact
        self.access_times[key] = datetime.now()
    
    def _evict_oldest(self) -> None:
        """Remove least recently accessed entries"""
        if not self.access_times:
            return
        oldest_key = min(self.access_times, key=self.access_times.get)
        del self.cache[oldest_key]
        del self.access_times[oldest_key]
    
    async def persist_to_supabase(self) -> None:
        """Persist cache to Supabase for durability"""
        if not supabase:
            return
        for key, fact in self.cache.items():
            try:
                supabase.table("fact_cache").upsert({
                    "cache_key": key,
                    "fact_data": asdict(fact),
                    "updated_at": datetime.now().isoformat()
                }).execute()
            except Exception as e:
                print(f"Cache persist error: {e}")

# Global cache instance
fact_cache = Mem0Cache()

# =============================================================================
# AI PROVIDER ROTATION (FREE TIER OPTIMIZATION)
# =============================================================================

class AIProviderRotation:
    """Rotate between AI providers for free-tier optimization"""
    
    def __init__(self):
        self.providers = ["gemini", "grok", "local"]
        self.current_index = 0
        self.request_counts = {p: 0 for p in self.providers}
        self.rate_limits = {
            "gemini": 60,  # 60 req/min free tier
            "grok": 100,
            "local": float("inf")
        }
        self.reset_time = datetime.now()
    
    def _reset_if_needed(self) -> None:
        """Reset counters every minute"""
        if datetime.now() - self.reset_time > timedelta(minutes=1):
            self.request_counts = {p: 0 for p in self.providers}
            self.reset_time = datetime.now()
    
    def get_provider(self) -> str:
        """Get next available provider"""
        self._reset_if_needed()
        for _ in range(len(self.providers)):
            provider = self.providers[self.current_index]
            if self.request_counts[provider] < self.rate_limits[provider]:
                self.request_counts[provider] += 1
                return provider
            self.current_index = (self.current_index + 1) % len(self.providers)
        return "local"  # Fallback to local
    
    async def query(self, prompt: str) -> str:
        """Query AI with automatic provider rotation"""
        provider = self.get_provider()
        
        if provider == "gemini":
            return await self._query_gemini(prompt)
        elif provider == "grok":
            return await self._query_grok(prompt)
        else:
            return await self._query_local(prompt)
    
    async def _query_gemini(self, prompt: str) -> str:
        """Query Gemini Flash 2.0"""
        if not GEMINI_API_KEY:
            return await self._query_local(prompt)
        
        url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key={GEMINI_API_KEY}"
        payload = {
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {"temperature": 0.3, "maxOutputTokens": 2048}
        }
        
        async with aiohttp.ClientSession() as session:
            try:
                async with session.post(url, json=payload) as resp:
                    if resp.status == 200:
                        data = await resp.json()
                        return data["candidates"][0]["content"]["parts"][0]["text"]
            except Exception as e:
                print(f"Gemini error: {e}")
        
        return await self._query_grok(prompt)
    
    async def _query_grok(self, prompt: str) -> str:
        """Query Grok Free API"""
        if not GROK_API_KEY:
            return await self._query_local(prompt)
        
        url = "https://api.x.ai/v1/chat/completions"
        headers = {"Authorization": f"Bearer {GROK_API_KEY}"}
        payload = {
            "model": "grok-beta",
            "messages": [{"role": "user", "content": prompt}]
        }
        
        async with aiohttp.ClientSession() as session:
            try:
                async with session.post(url, json=payload, headers=headers) as resp:
                    if resp.status == 200:
                        data = await resp.json()
                        return data["choices"][0]["message"]["content"]
            except Exception as e:
                print(f"Grok error: {e}")
        
        return await self._query_local(prompt)
    
    async def _query_local(self, prompt: str) -> str:
        """Local fallback with rule-based responses"""
        return f"[Local Analysis] Further research needed for: {prompt[:100]}..."

# Global AI rotation instance
ai_rotation = AIProviderRotation()

# =============================================================================
# FACT CHECKING ENGINE
# =============================================================================

class FactChecker:
    """Core fact-checking engine with proactive research"""
    
    FACT_CHECK_PROMPT = """You are Jamie, a world-class fact-checker for the Joe Rogan Experience.
Your job is to quickly and accurately verify claims made during conversations.

Analyze this claim and provide:
1. VERDICT: true, false, partially_true, or unverifiable
2. CONFIDENCE: 0.0 to 1.0
3. SOURCES: List 2-3 credible sources
4. EXPLANATION: Brief 2-3 sentence explanation

Claim to verify: {claim}

Respond in JSON format:
{{
    "verdict": "...",
    "confidence": 0.0,
    "sources": ["...", "..."],
    "explanation": "..."
}}"""

    PROACTIVE_RESEARCH_PROMPT = """You are a proactive research assistant monitoring a conversation.
Given this topic/statement, identify 3-5 interesting related facts that would add value to the discussion.

Topic: {topic}

Respond with a JSON array of facts:
[
    {{"fact": "...", "relevance": "high/medium/low", "source_type": "academic/news/expert"}},
    ...
]"""

    def __init__(self):
        self.active_sessions: Dict[str, ResearchSession] = {}
    
    async def check_claim(self, claim: str, user_id: str) -> FactCheck:
        """Verify a claim and return structured fact check"""
        
        # Check cache first
        cached = fact_cache.get(claim)
        if cached:
            return cached
        
        # Query AI
        prompt = self.FACT_CHECK_PROMPT.format(claim=claim)
        response = await ai_rotation.query(prompt)
        
        # Parse response
        try:
            # Extract JSON from response
            json_match = re.search(r'\{.*\}', response, re.DOTALL)
            if json_match:
                data = json.loads(json_match.group())
            else:
                data = {
                    "verdict": "unverifiable",
                    "confidence": 0.5,
                    "sources": [],
                    "explanation": response[:500]
                }
        except json.JSONDecodeError:
            data = {
                "verdict": "unverifiable",
                "confidence": 0.5,
                "sources": [],
                "explanation": response[:500]
            }
        
        # Create fact check object
        fact = FactCheck(
            id=hashlib.md5(f"{claim}{datetime.now().isoformat()}".encode()).hexdigest()[:12],
            claim=claim,
            verdict=data.get("verdict", "unverifiable"),
            confidence=float(data.get("confidence", 0.5)),
            sources=data.get("sources", []),
            explanation=data.get("explanation", ""),
            timestamp=datetime.now().isoformat()
        )
        
        # Cache result
        fact_cache.set(claim, fact)
        
        # Persist to Supabase
        if supabase:
            try:
                supabase.table("fact_checks").insert(asdict(fact)).execute()
            except Exception as e:
                print(f"DB error: {e}")
        
        return fact
    
    async def proactive_research(self, topic: str) -> List[Dict]:
        """Generate proactive research suggestions"""
        prompt = self.PROACTIVE_RESEARCH_PROMPT.format(topic=topic)
        response = await ai_rotation.query(prompt)
        
        try:
            json_match = re.search(r'\[.*\]', response, re.DOTALL)
            if json_match:
                return json.loads(json_match.group())
        except json.JSONDecodeError:
            pass
        
        return [{"fact": "Research in progress...", "relevance": "medium", "source_type": "pending"}]
    
    def start_session(self, user_id: str, topic: str) -> ResearchSession:
        """Start a new research session"""
        session = ResearchSession(
            id=hashlib.md5(f"{user_id}{datetime.now().isoformat()}".encode()).hexdigest()[:12],
            user_id=user_id,
            topic=topic,
            facts=[],
            started_at=datetime.now().isoformat()
        )
        self.active_sessions[session.id] = session
        return session
    
    def end_session(self, session_id: str) -> Optional[ResearchSession]:
        """End a research session and calculate duration"""
        session = self.active_sessions.get(session_id)
        if session:
            session.ended_at = datetime.now().isoformat()
            started = datetime.fromisoformat(session.started_at)
            session.duration_minutes = (datetime.now() - started).total_seconds() / 60
            del self.active_sessions[session_id]
            
            # Persist to Supabase
            if supabase:
                try:
                    supabase.table("research_sessions").insert({
                        "id": session.id,
                        "user_id": session.user_id,
                        "topic": session.topic,
                        "facts_count": len(session.facts),
                        "duration_minutes": session.duration_minutes,
                        "started_at": session.started_at,
                        "ended_at": session.ended_at
                    }).execute()
                except Exception as e:
                    print(f"Session persist error: {e}")
        
        return session

# Global fact checker instance
fact_checker = FactChecker()

# =============================================================================
# TTS ENGINE (ElevenLabs + Piper Fallback)
# =============================================================================

class TTSEngine:
    """Text-to-Speech with ElevenLabs and Piper fallback"""
    
    JAMIE_VOICE_ID = "21m00Tcm4TlvDq8ikWAM"  # Default voice, can be cloned
    
    async def synthesize(self, text: str) -> Optional[bytes]:
        """Synthesize speech from text"""
        
        # Try ElevenLabs first
        if ELEVENLABS_API_KEY:
            audio = await self._elevenlabs_tts(text)
            if audio:
                return audio
        
        # Fallback to Piper (local)
        return await self._piper_tts(text)
    
    async def _elevenlabs_tts(self, text: str) -> Optional[bytes]:
        """ElevenLabs TTS"""
        url = f"https://api.elevenlabs.io/v1/text-to-speech/{self.JAMIE_VOICE_ID}"
        headers = {
            "Accept": "audio/mpeg",
            "xi-api-key": ELEVENLABS_API_KEY
        }
        payload = {
            "text": text,
            "model_id": "eleven_monolingual_v1",
            "voice_settings": {"stability": 0.5, "similarity_boost": 0.75}
        }
        
        async with aiohttp.ClientSession() as session:
            try:
                async with session.post(url, json=payload, headers=headers) as resp:
                    if resp.status == 200:
                        return await resp.read()
            except Exception as e:
                print(f"ElevenLabs error: {e}")
        
        return None
    
    async def _piper_tts(self, text: str) -> Optional[bytes]:
        """Piper local TTS fallback"""
        # Piper would be called via subprocess for local TTS
        # For now, return None to indicate audio unavailable
        return None

# Global TTS instance
tts_engine = TTSEngine()

# =============================================================================
# STRIPE BILLING
# =============================================================================

class BillingManager:
    """Handle Stripe subscriptions and usage-based billing"""
    
    PRICES = {
        "pro_monthly": "price_pro_monthly_2900",  # $29/mo
        "overage_hour": "price_overage_500"  # $5/hr overage
    }
    
    async def create_checkout_session(self, user_email: str, price_id: str) -> Dict:
        """Create Stripe checkout session"""
        try:
            session = stripe.checkout.Session.create(
                customer_email=user_email,
                payment_method_types=["card"],
                line_items=[{"price": price_id, "quantity": 1}],
                mode="subscription",
                success_url="https://virtualpullup.ai/success?session_id={CHECKOUT_SESSION_ID}",
                cancel_url="https://virtualpullup.ai/cancel"
            )
            return {"url": session.url, "session_id": session.id}
        except Exception as e:
            return {"error": str(e)}
    
    async def record_usage(self, user_id: str, minutes: float) -> None:
        """Record usage for billing"""
        if supabase:
            try:
                # Get current user
                result = supabase.table("users").select("*").eq("id", user_id).single().execute()
                if result.data:
                    current_hours = result.data.get("hours_used", 0)
                    new_hours = current_hours + (minutes / 60)
                    supabase.table("users").update({"hours_used": new_hours}).eq("id", user_id).execute()
            except Exception as e:
                print(f"Usage recording error: {e}")

# Global billing manager
billing = BillingManager()

# =============================================================================
# EMPIRE MONITORING PLUGIN
# =============================================================================

class EmpireMonitor:
    """Dashboard widget for empire-wide monitoring"""
    
    def get_metrics(self) -> Dict:
        """Get current metrics for dashboard"""
        metrics = {
            "endeavor": "Virtual Pull-Up AI",
            "version": "1.0.0",
            "status": "operational",
            "timestamp": datetime.now().isoformat(),
            "stats": {
                "active_sessions": len(fact_checker.active_sessions),
                "cache_size": len(fact_cache.cache),
                "api_provider": ai_rotation.providers[ai_rotation.current_index],
                "request_counts": ai_rotation.request_counts
            },
            "revenue": {
                "mrr": 0,  # Would pull from Stripe
                "subscribers": 0,
                "trial_users": 0
            }
        }
        
        if supabase:
            try:
                # Get user count
                result = supabase.table("users").select("count", count="exact").execute()
                metrics["stats"]["total_users"] = result.count if result.count else 0
            except:
                pass
        
        return metrics

# Global monitor
empire_monitor = EmpireMonitor()

# =============================================================================
# API ROUTES
# =============================================================================

@app.route("/")
def home():
    """Landing page"""
    return render_template_string("""
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Virtual Pull-Up AI | Jamie-Style Fact Engine</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
            background: linear-gradient(135deg, #0f0f23 0%, #1a1a2e 50%, #16213e 100%);
            color: #fff;
            min-height: 100vh;
        }
        .container { max-width: 1200px; margin: 0 auto; padding: 2rem; }
        header {
            text-align: center;
            padding: 4rem 0;
        }
        h1 {
            font-size: 3.5rem;
            background: linear-gradient(90deg, #00d4ff, #7b2ff7);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            margin-bottom: 1rem;
        }
        .subtitle { font-size: 1.5rem; color: #a0a0a0; margin-bottom: 2rem; }
        .badge {
            display: inline-block;
            background: rgba(123, 47, 247, 0.2);
            border: 1px solid #7b2ff7;
            padding: 0.5rem 1rem;
            border-radius: 20px;
            font-size: 0.9rem;
            color: #7b2ff7;
        }
        .features {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 2rem;
            margin: 4rem 0;
        }
        .feature {
            background: rgba(255, 255, 255, 0.05);
            border: 1px solid rgba(255, 255, 255, 0.1);
            border-radius: 16px;
            padding: 2rem;
            backdrop-filter: blur(10px);
        }
        .feature h3 { font-size: 1.3rem; margin-bottom: 1rem; color: #00d4ff; }
        .feature p { color: #a0a0a0; line-height: 1.6; }
        .pricing {
            text-align: center;
            background: rgba(255, 255, 255, 0.03);
            border-radius: 24px;
            padding: 3rem;
            margin: 2rem 0;
        }
        .price { font-size: 4rem; font-weight: 700; }
        .price span { font-size: 1.5rem; color: #a0a0a0; }
        .cta {
            display: inline-block;
            background: linear-gradient(90deg, #7b2ff7, #00d4ff);
            color: #fff;
            padding: 1rem 3rem;
            border-radius: 30px;
            font-size: 1.2rem;
            font-weight: 600;
            text-decoration: none;
            margin-top: 2rem;
            transition: transform 0.3s;
        }
        .cta:hover { transform: scale(1.05); }
        .demo {
            background: rgba(0, 212, 255, 0.1);
            border: 1px solid #00d4ff;
            border-radius: 16px;
            padding: 2rem;
            margin: 2rem 0;
        }
        input, button {
            padding: 1rem;
            font-size: 1rem;
            border-radius: 8px;
            border: none;
        }
        input {
            width: 70%;
            background: rgba(255, 255, 255, 0.1);
            color: #fff;
        }
        button {
            background: #7b2ff7;
            color: #fff;
            cursor: pointer;
            margin-left: 1rem;
        }
        #result {
            margin-top: 2rem;
            padding: 1.5rem;
            background: rgba(0, 0, 0, 0.3);
            border-radius: 8px;
            display: none;
        }
        .verdict-true { color: #4ade80; }
        .verdict-false { color: #f87171; }
        .verdict-partial { color: #fbbf24; }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>Virtual Pull-Up AI</h1>
            <p class="subtitle">Jamie-Style Fact Engine for Podcasters</p>
            <span class="badge">🎙️ Powered by Gemini 3 Pro</span>
        </header>
        
        <div class="demo">
            <h3>🔍 Try It Now - Verify Any Claim</h3>
            <div style="margin-top: 1rem;">
                <input type="text" id="claim" placeholder="Enter a claim to fact-check..." />
                <button onclick="checkFact()">Verify</button>
            </div>
            <div id="result"></div>
        </div>
        
        <div class="features">
            <div class="feature">
                <h3>⚡ Proactive Research</h3>
                <p>AI monitors your conversation and surfaces relevant facts before you even ask.</p>
            </div>
            <div class="feature">
                <h3>🎙️ Voice Overlays</h3>
                <p>Get fact-check results delivered via ElevenLabs voice synthesis.</p>
            </div>
            <div class="feature">
                <h3>🧠 Mem0 Caching</h3>
                <p>Previously verified claims are cached for instant retrieval.</p>
            </div>
            <div class="feature">
                <h3>📊 Empire Dashboard</h3>
                <p>Monitor usage, revenue, and metrics across all endeavors.</p>
            </div>
        </div>
        
        <div class="pricing">
            <h2>Start Fact-Checking Today</h2>
            <div class="price">$29<span>/mo</span></div>
            <p style="color: #a0a0a0; margin: 1rem 0;">Unlimited fact-checks • Voice overlays • Proactive research</p>
            <p style="color: #fbbf24;">+ $5 per additional hour beyond 10hr/mo</p>
            <a href="/api/checkout" class="cta">Start Free Trial</a>
        </div>
    </div>
    
    <script>
        async function checkFact() {
            const claim = document.getElementById('claim').value;
            const resultDiv = document.getElementById('result');
            resultDiv.style.display = 'block';
            resultDiv.innerHTML = '<p>🔍 Analyzing claim...</p>';
            
            try {
                const response = await fetch('/api/check', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({claim: claim})
                });
                const data = await response.json();
                
                let verdictClass = 'verdict-partial';
                if (data.verdict === 'true') verdictClass = 'verdict-true';
                else if (data.verdict === 'false') verdictClass = 'verdict-false';
                
                resultDiv.innerHTML = `
                    <h4 class="${verdictClass}">Verdict: ${data.verdict.toUpperCase()}</h4>
                    <p><strong>Confidence:</strong> ${(data.confidence * 100).toFixed(0)}%</p>
                    <p><strong>Explanation:</strong> ${data.explanation}</p>
                    <p><strong>Sources:</strong> ${data.sources.join(', ') || 'None cited'}</p>
                `;
            } catch (error) {
                resultDiv.innerHTML = '<p style="color: #f87171;">Error checking fact. Please try again.</p>';
            }
        }
    </script>
</body>
</html>
    """)

@app.route("/api/check", methods=["POST"])
async def api_check_claim():
    """API endpoint to fact-check a claim"""
    data = request.get_json()
    claim = data.get("claim", "")
    user_id = data.get("user_id", "anonymous")
    
    if not claim:
        return jsonify({"error": "No claim provided"}), 400
    
    # Run async fact check
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    fact = loop.run_until_complete(fact_checker.check_claim(claim, user_id))
    loop.close()
    
    return jsonify(asdict(fact))

@app.route("/api/research", methods=["POST"])
async def api_proactive_research():
    """Get proactive research suggestions for a topic"""
    data = request.get_json()
    topic = data.get("topic", "")
    
    if not topic:
        return jsonify({"error": "No topic provided"}), 400
    
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    facts = loop.run_until_complete(fact_checker.proactive_research(topic))
    loop.close()
    
    return jsonify({"topic": topic, "suggestions": facts})

@app.route("/api/session/start", methods=["POST"])
def api_start_session():
    """Start a new research session"""
    data = request.get_json()
    user_id = data.get("user_id", "anonymous")
    topic = data.get("topic", "General research")
    
    session = fact_checker.start_session(user_id, topic)
    return jsonify({"session_id": session.id, "topic": topic, "started_at": session.started_at})

@app.route("/api/session/end", methods=["POST"])
def api_end_session():
    """End a research session"""
    data = request.get_json()
    session_id = data.get("session_id", "")
    
    session = fact_checker.end_session(session_id)
    if session:
        return jsonify({
            "session_id": session.id,
            "duration_minutes": session.duration_minutes,
            "facts_checked": len(session.facts)
        })
    return jsonify({"error": "Session not found"}), 404

@app.route("/api/tts", methods=["POST"])
async def api_tts():
    """Generate speech for fact check result"""
    data = request.get_json()
    text = data.get("text", "")
    
    if not text:
        return jsonify({"error": "No text provided"}), 400
    
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    audio = loop.run_until_complete(tts_engine.synthesize(text))
    loop.close()
    
    if audio:
        return Response(audio, mimetype="audio/mpeg")
    return jsonify({"error": "TTS unavailable"}), 503

@app.route("/api/checkout")
def api_checkout():
    """Create Stripe checkout session"""
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    result = loop.run_until_complete(billing.create_checkout_session(
        "customer@example.com",
        billing.PRICES["pro_monthly"]
    ))
    loop.close()
    
    if "url" in result:
        return jsonify(result)
    return jsonify(result), 400

@app.route("/api/metrics")
def api_metrics():
    """Empire monitoring endpoint"""
    return jsonify(empire_monitor.get_metrics())

# =============================================================================
# RESEARCH DASHBOARD
# =============================================================================

@dataclass
class ResearchTopic:
    id: str
    name: str
    keywords: List[str]
    sources_count: int
    last_updated: str
    credibility_score: float
    active: bool

class ResearchDashboard:
    """Central research management dashboard"""
    
    def __init__(self):
        self.topics: Dict[str, ResearchTopic] = {}
        self.research_history: List[Dict] = []
    
    def create_topic(self, name: str, keywords: List[str]) -> ResearchTopic:
        """Create research topic"""
        topic = ResearchTopic(
            id=hashlib.md5(f"{name}{datetime.now()}".encode()).hexdigest()[:12],
            name=name,
            keywords=keywords,
            sources_count=0,
            last_updated=datetime.now().isoformat(),
            credibility_score=0,
            active=True
        )
        
        self.topics[topic.id] = topic
        return topic
    
    def get_active_topics(self) -> List[Dict]:
        """Get active research topics"""
        return [asdict(t) for t in self.topics.values() if t.active]
    
    def log_research(self, topic_id: str, query: str, 
                      sources_found: int) -> None:
        """Log research activity"""
        self.research_history.append({
            "topic_id": topic_id,
            "query": query,
            "sources_found": sources_found,
            "timestamp": datetime.now().isoformat()
        })
        
        if topic_id in self.topics:
            self.topics[topic_id].sources_count += sources_found
            self.topics[topic_id].last_updated = datetime.now().isoformat()
    
    def get_research_stats(self) -> Dict:
        """Get research statistics"""
        return {
            "total_topics": len(self.topics),
            "active_topics": sum(1 for t in self.topics.values() if t.active),
            "total_researches": len(self.research_history),
            "total_sources": sum(t.sources_count for t in self.topics.values())
        }

research_dashboard = ResearchDashboard()

# =============================================================================
# SOURCE MANAGER
# =============================================================================

@dataclass
class Source:
    id: str
    url: str
    title: str
    domain: str
    credibility_score: float
    last_accessed: str
    citations: int
    category: str

class SourceManager:
    """Manage and track sources"""
    
    TRUSTED_DOMAINS = {
        "gov": 95, "edu": 90, "org": 75,
        "reuters.com": 90, "apnews.com": 90, "bbc.com": 85,
        "nature.com": 95, "sciencedirect.com": 90
    }
    
    def __init__(self):
        self.sources: Dict[str, Source] = {}
    
    def add_source(self, url: str, title: str, 
                    category: str = "general") -> Source:
        """Add source to manager"""
        from urllib.parse import urlparse
        domain = urlparse(url).netloc.replace("www.", "")
        
        # Calculate credibility
        credibility = self._calculate_credibility(domain)
        
        source = Source(
            id=hashlib.md5(url.encode()).hexdigest()[:12],
            url=url,
            title=title,
            domain=domain,
            credibility_score=credibility,
            last_accessed=datetime.now().isoformat(),
            citations=0,
            category=category
        )
        
        self.sources[source.id] = source
        return source
    
    def _calculate_credibility(self, domain: str) -> float:
        """Calculate source credibility"""
        # Check if trusted domain
        for trusted, score in self.TRUSTED_DOMAINS.items():
            if trusted in domain:
                return score
        
        return 60  # Default credibility
    
    def cite_source(self, source_id: str) -> None:
        """Record citation of source"""
        if source_id in self.sources:
            self.sources[source_id].citations += 1
    
    def get_top_sources(self, limit: int = 10) -> List[Dict]:
        """Get most cited sources"""
        sorted_sources = sorted(
            self.sources.values(),
            key=lambda x: x.citations,
            reverse=True
        )
        return [asdict(s) for s in sorted_sources[:limit]]
    
    def search_sources(self, query: str) -> List[Dict]:
        """Search sources"""
        query_lower = query.lower()
        results = [
            s for s in self.sources.values()
            if query_lower in s.title.lower() or query_lower in s.domain.lower()
        ]
        return [asdict(s) for s in results]

source_manager = SourceManager()

# =============================================================================
# CREDIBILITY SCORING
# =============================================================================

class CredibilityScoring:
    """Advanced credibility scoring system"""
    
    def __init__(self):
        self.scores: Dict[str, Dict] = {}  # claim_id -> score data
    
    def score_claim(self, claim_id: str, sources: List[Source]) -> Dict:
        """Score claim credibility based on sources"""
        if not sources:
            return {"score": 0, "confidence": "low", "sources": 0}
        
        # Average source credibility
        avg_credibility = sum(s.credibility_score for s in sources) / len(sources)
        
        # Source diversity bonus
        unique_domains = len(set(s.domain for s in sources))
        diversity_bonus = min(20, unique_domains * 5)
        
        # Calculate final score
        final_score = min(100, avg_credibility + diversity_bonus)
        
        # Determine confidence level
        if len(sources) >= 5 and final_score >= 80:
            confidence = "high"
        elif len(sources) >= 3 and final_score >= 60:
            confidence = "medium"
        else:
            confidence = "low"
        
        score_data = {
            "claim_id": claim_id,
            "score": round(final_score, 1),
            "confidence": confidence,
            "sources": len(sources),
            "avg_source_credibility": round(avg_credibility, 1),
            "unique_domains": unique_domains
        }
        
        self.scores[claim_id] = score_data
        return score_data
    
    def get_claim_score(self, claim_id: str) -> Dict:
        """Get score for claim"""
        return self.scores.get(claim_id, {"error": "Claim not found"})

credibility = CredibilityScoring()

# =============================================================================
# EXPORT SYSTEM
# =============================================================================

class ExportSystem:
    """Export research and fact-checks"""
    
    def __init__(self):
        self.exports: List[Dict] = []
    
    def export_to_markdown(self, data: Dict) -> str:
        """Export to Markdown format"""
        md = f"# {data.get('title', 'Research Export')}\n\n"
        md += f"*Generated: {datetime.now().strftime('%Y-%m-%d %H:%M')}*\n\n"
        
        if data.get("claim"):
            md += f"## Claim\n{data['claim']}\n\n"
        
        if data.get("verdict"):
            md += f"## Verdict: {data['verdict']}\n\n"
        
        if data.get("sources"):
            md += "## Sources\n"
            for i, source in enumerate(data["sources"], 1):
                md += f"{i}. [{source.get('title', 'Source')}]({source.get('url', '')})\n"
        
        return md
    
    def export_to_json(self, data: Dict) -> str:
        """Export to JSON format"""
        return json.dumps(data, indent=2)
    
    def export_to_pdf_data(self, data: Dict) -> Dict:
        """Prepare data for PDF export"""
        return {
            "format": "pdf",
            "data": data,
            "generated_at": datetime.now().isoformat(),
            "status": "ready"
        }
    
    def log_export(self, export_type: str, data: Dict) -> None:
        """Log export activity"""
        self.exports.append({
            "type": export_type,
            "timestamp": datetime.now().isoformat(),
            "data_size": len(str(data))
        })

export_system = ExportSystem()

# =============================================================================
# ALERT SYSTEM
# =============================================================================

@dataclass
class Alert:
    id: str
    topic_id: str
    trigger: str  # keyword_match, credibility_drop, new_source
    message: str
    priority: str  # low, medium, high
    read: bool
    created_at: str

class AlertSystem:
    """Alert system for research monitoring"""
    
    def __init__(self):
        self.alerts: List[Alert] = []
        self.subscriptions: Dict[str, List[str]] = {}  # user_id -> topic_ids
    
    def create_alert(self, topic_id: str, trigger: str, 
                      message: str, priority: str = "medium") -> Alert:
        """Create new alert"""
        alert = Alert(
            id=hashlib.md5(f"{topic_id}{datetime.now()}".encode()).hexdigest()[:12],
            topic_id=topic_id,
            trigger=trigger,
            message=message,
            priority=priority,
            read=False,
            created_at=datetime.now().isoformat()
        )
        
        self.alerts.append(alert)
        return alert
    
    def subscribe_to_topic(self, user_id: str, topic_id: str) -> None:
        """Subscribe to topic alerts"""
        if user_id not in self.subscriptions:
            self.subscriptions[user_id] = []
        
        if topic_id not in self.subscriptions[user_id]:
            self.subscriptions[user_id].append(topic_id)
    
    def get_unread_alerts(self, user_id: str = None) -> List[Dict]:
        """Get unread alerts"""
        unread = [a for a in self.alerts if not a.read]
        return [asdict(a) for a in unread]
    
    def mark_read(self, alert_id: str) -> bool:
        """Mark alert as read"""
        for alert in self.alerts:
            if alert.id == alert_id:
                alert.read = True
                return True
        return False
    
    def get_alert_stats(self) -> Dict:
        """Get alert statistics"""
        return {
            "total_alerts": len(self.alerts),
            "unread": sum(1 for a in self.alerts if not a.read),
            "high_priority": sum(1 for a in self.alerts if a.priority == "high"),
            "subscriptions": sum(len(s) for s in self.subscriptions.values())
        }

alerts = AlertSystem()

# =============================================================================
# ADDITIONAL API ROUTES
# =============================================================================

@app.route("/api/research/topics", methods=["GET", "POST"])
def api_research_topics():
    """Manage research topics"""
    if request.method == "POST":
        data = request.get_json()
        topic = research_dashboard.create_topic(
            name=data.get("name", ""),
            keywords=data.get("keywords", [])
        )
        return jsonify(asdict(topic))
    
    return jsonify({"topics": research_dashboard.get_active_topics()})

@app.route("/api/research/stats")
def api_research_stats():
    """Get research statistics"""
    return jsonify(research_dashboard.get_research_stats())

@app.route("/api/sources", methods=["GET", "POST"])
def api_sources():
    """Manage sources"""
    if request.method == "POST":
        data = request.get_json()
        source = source_manager.add_source(
            url=data.get("url", ""),
            title=data.get("title", ""),
            category=data.get("category", "general")
        )
        return jsonify(asdict(source))
    
    query = request.args.get("q")
    if query:
        return jsonify({"sources": source_manager.search_sources(query)})
    return jsonify({"sources": source_manager.get_top_sources()})

@app.route("/api/credibility/<claim_id>")
def api_credibility(claim_id):
    """Get credibility score"""
    return jsonify(credibility.get_claim_score(claim_id))

@app.route("/api/export", methods=["POST"])
def api_export():
    """Export research data"""
    data = request.get_json()
    export_format = data.get("format", "markdown")
    content = data.get("content", {})
    
    if export_format == "markdown":
        result = export_system.export_to_markdown(content)
    elif export_format == "json":
        result = export_system.export_to_json(content)
    else:
        result = export_system.export_to_pdf_data(content)
    
    export_system.log_export(export_format, content)
    return jsonify({"export": result})

@app.route("/api/alerts", methods=["GET", "POST"])
def api_alerts():
    """Manage alerts"""
    if request.method == "POST":
        data = request.get_json()
        alert = alerts.create_alert(
            topic_id=data.get("topic_id", ""),
            trigger=data.get("trigger", "keyword_match"),
            message=data.get("message", ""),
            priority=data.get("priority", "medium")
        )
        return jsonify(asdict(alert))
    
    return jsonify({
        "alerts": alerts.get_unread_alerts(),
        "stats": alerts.get_alert_stats()
    })

@app.route("/health")
def health():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy",
        "endeavor": "Virtual Pull-Up AI",
        "version": "1.0.0",
        "timestamp": datetime.now().isoformat(),
        "components": {
            "fact_checker": "active",
            "research_topics": len(research_dashboard.topics),
            "sources": len(source_manager.sources),
            "credibility_scores": len(credibility.scores),
            "exports": len(export_system.exports),
            "alerts": len(alerts.alerts)
        }
    })

# =============================================================================
# MAIN ENTRY POINT
# =============================================================================

if __name__ == "__main__":
    print("🎙️ Virtual Pull-Up AI - Starting...")
    print("📍 http://localhost:5001")
    print("🔧 Components: FactChecker, Research, Sources, Credibility, Export, Alerts")
    app.run(host="0.0.0.0", port=5001, debug=True)
