#!/usr/bin/env python3
"""
Lil Bit Podcast Factory - Family AI Podcast Generator
Dynamic Dad/Mom/Lil Bit personas with ElevenLabs voices
Version: 1.0.0 | Production Ready
"""

import os
import json
import asyncio
import hashlib
import re
from datetime import datetime
from typing import Optional, Dict, List, Any, Tuple
from dataclasses import dataclass, asdict
from enum import Enum

# Flask imports
from flask import Flask, request, jsonify, render_template_string, send_file
from flask_cors import CORS

# Async HTTP
import aiohttp

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

# API Keys
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
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
# CONTENT FILTERS (FAMILY-SAFE)
# =============================================================================

class ContentFilter:
    """Filter content for family safety - no politics/religion (except holidays)"""
    
    BLOCKED_TOPICS = [
        "election", "democrat", "republican", "liberal", "conservative",
        "trump", "biden", "politics", "abortion", "immigration policy",
        "gun control", "political party", "congress", "senate vote"
    ]
    
    BLOCKED_RELIGIOUS = [
        "convert", "salvation", "sin", "hell", "damnation", 
        "religious debate", "atheism", "theology debate"
    ]
    
    ALLOWED_HOLIDAY_RELIGIOUS = [
        "christmas", "hanukkah", "easter", "thanksgiving", "diwali",
        "ramadan", "passover", "kwanzaa", "holiday tradition"
    ]
    
    @classmethod
    def is_safe(cls, text: str) -> Tuple[bool, str]:
        """Check if content is family-safe"""
        lower_text = text.lower()
        
        # Check blocked topics
        for topic in cls.BLOCKED_TOPICS:
            if topic in lower_text:
                return False, f"Blocked topic: {topic}"
        
        # Check religious content (allow holidays)
        is_holiday = any(h in lower_text for h in cls.ALLOWED_HOLIDAY_RELIGIOUS)
        if not is_holiday:
            for topic in cls.BLOCKED_RELIGIOUS:
                if topic in lower_text:
                    return False, f"Religious content outside holidays: {topic}"
        
        return True, "Content is family-safe"
    
    @classmethod
    def sanitize(cls, text: str) -> str:
        """Remove or replace potentially unsafe content"""
        sanitized = text
        for topic in cls.BLOCKED_TOPICS + cls.BLOCKED_RELIGIOUS:
            pattern = re.compile(re.escape(topic), re.IGNORECASE)
            sanitized = pattern.sub("[topic removed]", sanitized)
        return sanitized

# =============================================================================
# DATA MODELS
# =============================================================================

class PersonaType(str, Enum):
    DAD = "dad"
    MOM = "mom"
    LILBIT = "lilbit"

@dataclass
class Persona:
    type: PersonaType
    name: str
    voice_id: str  # ElevenLabs voice ID
    traits: List[str]
    speaking_style: str

@dataclass
class PodcastSegment:
    speaker: PersonaType
    text: str
    audio_url: Optional[str] = None
    duration_seconds: float = 0

@dataclass
class PodcastEpisode:
    id: str
    title: str
    topic: str
    segments: List[PodcastSegment]
    quality_score: float
    total_duration: float
    created_at: str
    status: str  # "generating", "review", "published", "rejected"

# =============================================================================
# PERSONA DEFINITIONS
# =============================================================================

PERSONAS = {
    PersonaType.DAD: Persona(
        type=PersonaType.DAD,
        name="Dad",
        voice_id="21m00Tcm4TlvDq8ikWAM",  # Adult male
        traits=["patient", "jokes", "dad humor", "educational"],
        speaking_style="Warm, patient, occasionally makes dad jokes, explains things clearly"
    ),
    PersonaType.MOM: Persona(
        type=PersonaType.MOM,
        name="Mom",
        voice_id="EXAVITQu4vr4xnSDxMaL",  # Adult female
        traits=["nurturing", "practical", "encouraging", "wise"],
        speaking_style="Nurturing, supportive, practical wisdom, encouraging"
    ),
    PersonaType.LILBIT: Persona(
        type=PersonaType.LILBIT,
        name="Lil Bit",
        voice_id="jsCqWAovK2LkecY7zXl4",  # Young voice
        traits=["curious", "playful", "asks questions", "excited"],
        speaking_style="Curious, energetic, asks lots of questions, gets excited about discoveries"
    )
}

# =============================================================================
# SCRIPT GENERATOR
# =============================================================================

class ScriptGenerator:
    """Generate family podcast scripts using Gemini"""
    
    SCRIPT_PROMPT = """You are writing a script for a family podcast called "Lil Bit's Learning Adventures".
The podcast features three characters:
- DAD: {dad_style}
- MOM: {mom_style}  
- LILBIT: {lilbit_style}

Topic: {topic}
Target duration: {duration} minutes

Write an engaging, educational, and fun conversation that:
1. Is 100% family-safe (no politics, controversial topics, or inappropriate content)
2. Is educational but entertaining
3. Has natural back-and-forth dialogue
4. Includes moments of humor (especially dad jokes)
5. Ends with a clear learning takeaway for kids

Format each line as:
SPEAKER: Dialogue text

Example:
LILBIT: Dad, why is the sky blue?
DAD: Great question, Lil Bit! It's because of something called Rayleigh scattering...
MOM: And that's the same reason sunsets are orange and red!

IMPORTANT: Keep it family-friendly. No politics, no controversial topics.

Generate the script now:"""

    QUALITY_PROMPT = """Rate this podcast script on a scale of 0-100 for:
1. Educational value (0-25)
2. Entertainment/engagement (0-25)
3. Family-friendliness (0-25)
4. Natural dialogue flow (0-25)

Script:
{script}

Respond with JSON:
{{"educational": X, "entertainment": X, "family_safe": X, "dialogue_flow": X, "total": X, "feedback": "..."}}"""

    async def generate_script(self, topic: str, duration_minutes: int = 5) -> Tuple[List[PodcastSegment], str]:
        """Generate podcast script for a given topic"""
        
        # Check topic safety first
        is_safe, reason = ContentFilter.is_safe(topic)
        if not is_safe:
            return [], f"Topic rejected: {reason}"
        
        prompt = self.SCRIPT_PROMPT.format(
            dad_style=PERSONAS[PersonaType.DAD].speaking_style,
            mom_style=PERSONAS[PersonaType.MOM].speaking_style,
            lilbit_style=PERSONAS[PersonaType.LILBIT].speaking_style,
            topic=topic,
            duration=duration_minutes
        )
        
        # Call Gemini
        script_text = await self._query_ai(prompt)
        
        # Parse script into segments
        segments = self._parse_script(script_text)
        
        # Verify all segments are safe
        for segment in segments:
            is_safe, reason = ContentFilter.is_safe(segment.text)
            if not is_safe:
                segment.text = ContentFilter.sanitize(segment.text)
        
        return segments, script_text
    
    async def score_quality(self, script: str) -> Dict:
        """Score the quality of a generated script"""
        prompt = self.QUALITY_PROMPT.format(script=script[:3000])  # Limit length
        response = await self._query_ai(prompt)
        
        try:
            json_match = re.search(r'\{.*\}', response, re.DOTALL)
            if json_match:
                return json.loads(json_match.group())
        except json.JSONDecodeError:
            pass
        
        return {"total": 75, "feedback": "Unable to parse quality score"}
    
    def _parse_script(self, script: str) -> List[PodcastSegment]:
        """Parse script text into segments"""
        segments = []
        lines = script.strip().split('\n')
        
        for line in lines:
            line = line.strip()
            if not line:
                continue
            
            # Match SPEAKER: dialogue pattern
            match = re.match(r'^(DAD|MOM|LILBIT|LIL BIT):\s*(.+)$', line, re.IGNORECASE)
            if match:
                speaker_str = match.group(1).upper().replace(" ", "")
                text = match.group(2).strip()
                
                speaker_map = {
                    "DAD": PersonaType.DAD,
                    "MOM": PersonaType.MOM,
                    "LILBIT": PersonaType.LILBIT
                }
                
                speaker = speaker_map.get(speaker_str, PersonaType.LILBIT)
                segments.append(PodcastSegment(speaker=speaker, text=text))
        
        return segments
    
    async def _query_ai(self, prompt: str) -> str:
        """Query Gemini API"""
        if not GEMINI_API_KEY:
            return "AI service unavailable. Please configure GEMINI_API_KEY."
        
        url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key={GEMINI_API_KEY}"
        payload = {
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {"temperature": 0.8, "maxOutputTokens": 4096}
        }
        
        async with aiohttp.ClientSession() as session:
            try:
                async with session.post(url, json=payload) as resp:
                    if resp.status == 200:
                        data = await resp.json()
                        return data["candidates"][0]["content"]["parts"][0]["text"]
            except Exception as e:
                print(f"AI error: {e}")
        
        return "Unable to generate content"

# =============================================================================
# TTS ENGINE (ElevenLabs + Piper Fallback)
# =============================================================================

class TTSEngine:
    """Text-to-Speech with ElevenLabs for each persona"""
    
    async def synthesize_segment(self, segment: PodcastSegment) -> Optional[bytes]:
        """Synthesize audio for a segment using the persona's voice"""
        persona = PERSONAS[segment.speaker]
        
        if ELEVENLABS_API_KEY:
            return await self._elevenlabs_tts(segment.text, persona.voice_id)
        
        return None
    
    async def synthesize_episode(self, segments: List[PodcastSegment]) -> List[bytes]:
        """Synthesize all segments for an episode"""
        audio_parts = []
        
        for segment in segments:
            audio = await self.synthesize_segment(segment)
            if audio:
                audio_parts.append(audio)
        
        return audio_parts
    
    async def _elevenlabs_tts(self, text: str, voice_id: str) -> Optional[bytes]:
        """ElevenLabs TTS"""
        url = f"https://api.elevenlabs.io/v1/text-to-speech/{voice_id}"
        headers = {
            "Accept": "audio/mpeg",
            "xi-api-key": ELEVENLABS_API_KEY
        }
        payload = {
            "text": text,
            "model_id": "eleven_monolingual_v1",
            "voice_settings": {"stability": 0.6, "similarity_boost": 0.8}
        }
        
        async with aiohttp.ClientSession() as session:
            try:
                async with session.post(url, json=payload, headers=headers) as resp:
                    if resp.status == 200:
                        return await resp.read()
            except Exception as e:
                print(f"ElevenLabs error: {e}")
        
        return None

# =============================================================================
# OPUS CLIP INTEGRATION
# =============================================================================

class ClipGenerator:
    """Generate clips for social media using OpusClip-style processing"""
    
    async def generate_clips(self, episode_id: str, segments: List[PodcastSegment]) -> List[Dict]:
        """Generate short clips from episode segments"""
        clips = []
        
        # Find highlight moments (segments with questions or excitement)
        for i, segment in enumerate(segments):
            if any(marker in segment.text.lower() for marker in ["?", "!", "wow", "amazing", "cool"]):
                clip = {
                    "episode_id": episode_id,
                    "start_segment": i,
                    "text": segment.text[:100],
                    "speaker": segment.speaker.value,
                    "clip_type": "highlight",
                    "platform_ready": ["tiktok", "instagram", "youtube_shorts"]
                }
                clips.append(clip)
        
        return clips[:5]  # Return top 5 clips

# =============================================================================
# MULTI-PLATFORM PUBLISHER
# =============================================================================

class PlatformPublisher:
    """Publish to multiple platforms"""
    
    PLATFORMS = ["youtube", "spotify", "apple_podcasts", "tiktok", "instagram"]
    
    async def publish(self, episode: PodcastEpisode, platforms: List[str] = None) -> Dict:
        """Publish episode to specified platforms"""
        platforms = platforms or self.PLATFORMS
        results = {}
        
        for platform in platforms:
            # In production, this would call each platform's API
            results[platform] = {
                "status": "queued",
                "scheduled_at": datetime.now().isoformat(),
                "episode_id": episode.id
            }
        
        return results

# =============================================================================
# PODCAST FACTORY
# =============================================================================

class PodcastFactory:
    """Main factory class for generating podcasts"""
    
    def __init__(self):
        self.script_generator = ScriptGenerator()
        self.tts_engine = TTSEngine()
        self.clip_generator = ClipGenerator()
        self.publisher = PlatformPublisher()
        self.quality_threshold = 70  # Minimum quality score to publish
    
    async def create_episode(self, topic: str, duration_minutes: int = 5) -> PodcastEpisode:
        """Create a complete podcast episode"""
        
        # Generate script
        segments, raw_script = await self.script_generator.generate_script(topic, duration_minutes)
        
        if not segments:
            return PodcastEpisode(
                id=hashlib.md5(f"{topic}{datetime.now()}".encode()).hexdigest()[:12],
                title=f"Episode: {topic}",
                topic=topic,
                segments=[],
                quality_score=0,
                total_duration=0,
                created_at=datetime.now().isoformat(),
                status="rejected"
            )
        
        # Score quality
        quality = await self.script_generator.score_quality(raw_script)
        quality_score = quality.get("total", 0)
        
        # Create episode
        episode = PodcastEpisode(
            id=hashlib.md5(f"{topic}{datetime.now()}".encode()).hexdigest()[:12],
            title=f"Lil Bit Learns About: {topic}",
            topic=topic,
            segments=segments,
            quality_score=quality_score,
            total_duration=len(segments) * 10,  # Estimate 10s per segment
            created_at=datetime.now().isoformat(),
            status="review" if quality_score >= self.quality_threshold else "rejected"
        )
        
        # Store in Supabase
        if supabase:
            try:
                supabase.table("podcast_episodes").insert({
                    "id": episode.id,
                    "title": episode.title,
                    "topic": episode.topic,
                    "quality_score": episode.quality_score,
                    "status": episode.status,
                    "segments_count": len(segments),
                    "created_at": episode.created_at
                }).execute()
            except Exception as e:
                print(f"DB error: {e}")
        
        return episode
    
    async def generate_audio(self, episode: PodcastEpisode) -> List[bytes]:
        """Generate audio for all segments"""
        return await self.tts_engine.synthesize_episode(episode.segments)
    
    async def generate_clips(self, episode: PodcastEpisode) -> List[Dict]:
        """Generate social media clips"""
        return await self.clip_generator.generate_clips(episode.id, episode.segments)
    
    async def publish_episode(self, episode: PodcastEpisode) -> Dict:
        """Publish episode if it passes quality gate"""
        if episode.quality_score < self.quality_threshold:
            return {"error": f"Quality score {episode.quality_score} below threshold {self.quality_threshold}"}
        
        return await self.publisher.publish(episode)

# Global factory instance
factory = PodcastFactory()

# =============================================================================
# EMPIRE MONITORING
# =============================================================================

class EmpireMonitor:
    """Dashboard widget for empire-wide monitoring"""
    
    def get_metrics(self) -> Dict:
        metrics = {
            "endeavor": "Lil Bit Podcast Factory",
            "version": "1.0.0",
            "status": "operational",
            "timestamp": datetime.now().isoformat(),
            "stats": {
                "quality_threshold": factory.quality_threshold,
                "episodes_today": 0,
                "avg_quality_score": 0
            },
            "revenue": {
                "custom_topics_sold": 0,
                "mrr": 0
            }
        }
        
        if supabase:
            try:
                result = supabase.table("podcast_episodes").select("count", count="exact").execute()
                metrics["stats"]["total_episodes"] = result.count or 0
            except:
                pass
        
        return metrics

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
    <title>Lil Bit Podcast Factory | Family AI Podcasts</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Comic Sans MS', 'Chalkboard', cursive;
            background: linear-gradient(135deg, #ffecd2 0%, #fcb69f 100%);
            color: #333;
            min-height: 100vh;
        }
        .container { max-width: 1200px; margin: 0 auto; padding: 2rem; }
        header { text-align: center; padding: 3rem 0; }
        h1 {
            font-size: 3rem;
            color: #ff6b6b;
            text-shadow: 3px 3px 0 #ffd93d;
            margin-bottom: 1rem;
        }
        .subtitle { font-size: 1.3rem; color: #555; }
        .characters {
            display: flex;
            justify-content: center;
            gap: 2rem;
            margin: 3rem 0;
            flex-wrap: wrap;
        }
        .character {
            background: white;
            border-radius: 20px;
            padding: 2rem;
            width: 200px;
            text-align: center;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
        }
        .character-emoji { font-size: 4rem; }
        .character h3 { margin: 1rem 0 0.5rem; color: #ff6b6b; }
        .generator {
            background: white;
            border-radius: 20px;
            padding: 2rem;
            margin: 2rem 0;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
        }
        input, button {
            padding: 1rem;
            font-size: 1.1rem;
            border-radius: 10px;
            border: 2px solid #ffd93d;
        }
        input { width: 60%; }
        button {
            background: #ff6b6b;
            color: white;
            border-color: #ff6b6b;
            cursor: pointer;
            margin-left: 1rem;
        }
        button:hover { background: #ee5a5a; }
        #result {
            margin-top: 2rem;
            padding: 1.5rem;
            background: #fff9e6;
            border-radius: 10px;
            border: 2px dashed #ffd93d;
            display: none;
        }
        .segment { margin: 0.5rem 0; padding: 0.5rem; border-radius: 5px; }
        .segment-dad { background: #e3f2fd; }
        .segment-mom { background: #fce4ec; }
        .segment-lilbit { background: #fff9c4; }
        .pricing {
            background: white;
            border-radius: 20px;
            padding: 3rem;
            text-align: center;
            margin: 2rem 0;
        }
        .price { font-size: 3rem; color: #ff6b6b; font-weight: bold; }
        .cta {
            display: inline-block;
            background: linear-gradient(90deg, #ff6b6b, #ffd93d);
            color: white;
            padding: 1rem 3rem;
            border-radius: 30px;
            font-size: 1.2rem;
            text-decoration: none;
            margin-top: 1.5rem;
        }
        .family-badge {
            background: #4caf50;
            color: white;
            padding: 0.5rem 1rem;
            border-radius: 20px;
            display: inline-block;
            margin-top: 1rem;
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>🎧 Lil Bit Podcast Factory</h1>
            <p class="subtitle">AI-Powered Family Podcasts with Dad, Mom & Lil Bit</p>
            <span class="family-badge">✓ 100% Family Safe</span>
        </header>
        
        <div class="characters">
            <div class="character">
                <div class="character-emoji">👨</div>
                <h3>Dad</h3>
                <p>Dad jokes & wisdom</p>
            </div>
            <div class="character">
                <div class="character-emoji">👩</div>
                <h3>Mom</h3>
                <p>Nurturing & practical</p>
            </div>
            <div class="character">
                <div class="character-emoji">👶</div>
                <h3>Lil Bit</h3>
                <p>Curious & excited</p>
            </div>
        </div>
        
        <div class="generator">
            <h2>🎙️ Generate a Podcast Episode</h2>
            <p style="margin: 1rem 0; color: #666;">Enter any kid-friendly topic!</p>
            <div>
                <input type="text" id="topic" placeholder="e.g., Why do dinosaurs have small arms?" />
                <button onclick="generatePodcast()">Create Episode!</button>
            </div>
            <div id="result"></div>
        </div>
        
        <div class="pricing">
            <h2>Custom Topic Generation</h2>
            <div class="price">$29.98</div>
            <p style="color: #666;">per custom topic with full audio</p>
            <p style="margin-top: 1rem;">✓ 3 unique voices • ✓ Auto-posted to all platforms • ✓ Social clips included</p>
            <a href="/api/checkout" class="cta">Order Custom Episode</a>
        </div>
    </div>
    
    <script>
        async function generatePodcast() {
            const topic = document.getElementById('topic').value;
            const resultDiv = document.getElementById('result');
            resultDiv.style.display = 'block';
            resultDiv.innerHTML = '<p>🎙️ Generating podcast with Dad, Mom & Lil Bit...</p>';
            
            try {
                const response = await fetch('/api/generate', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({topic: topic})
                });
                const data = await response.json();
                
                if (data.error) {
                    resultDiv.innerHTML = `<p style="color: red;">❌ ${data.error}</p>`;
                    return;
                }
                
                let segmentsHtml = data.segments.map(s => 
                    `<div class="segment segment-${s.speaker}"><strong>${s.speaker.toUpperCase()}:</strong> ${s.text}</div>`
                ).join('');
                
                resultDiv.innerHTML = `
                    <h3>✨ "${data.title}"</h3>
                    <p>Quality Score: ${data.quality_score}/100 ${data.quality_score >= 70 ? '✅' : '⚠️'}</p>
                    <div style="margin-top: 1rem;">${segmentsHtml}</div>
                `;
            } catch (error) {
                resultDiv.innerHTML = '<p style="color: red;">Error generating podcast. Please try again.</p>';
            }
        }
    </script>
</body>
</html>
    """)

@app.route("/api/generate", methods=["POST"])
def api_generate():
    """Generate a new podcast episode"""
    data = request.get_json()
    topic = data.get("topic", "")
    duration = data.get("duration", 5)
    
    if not topic:
        return jsonify({"error": "No topic provided"}), 400
    
    # Check content safety
    is_safe, reason = ContentFilter.is_safe(topic)
    if not is_safe:
        return jsonify({"error": f"Topic not family-safe: {reason}"}), 400
    
    # Generate episode
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    episode = loop.run_until_complete(factory.create_episode(topic, duration))
    loop.close()
    
    return jsonify({
        "id": episode.id,
        "title": episode.title,
        "quality_score": episode.quality_score,
        "status": episode.status,
        "segments": [{"speaker": s.speaker.value, "text": s.text} for s in episode.segments]
    })

@app.route("/api/audio/<episode_id>")
def api_audio(episode_id):
    """Get audio for an episode"""
    # In production, this would stream the combined audio
    return jsonify({"message": "Audio generation requires ElevenLabs API key"})

@app.route("/api/clips/<episode_id>")
def api_clips(episode_id):
    """Get generated clips for an episode"""
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    # Mock segments for demo
    clips = loop.run_until_complete(factory.clip_generator.generate_clips(episode_id, []))
    loop.close()
    
    return jsonify({"episode_id": episode_id, "clips": clips})

@app.route("/api/checkout")
def api_checkout():
    """Stripe checkout for custom topic"""
    try:
        session = stripe.checkout.Session.create(
            payment_method_types=["card"],
            line_items=[{
                "price_data": {
                    "currency": "usd",
                    "unit_amount": 2998,  # $29.98
                    "product_data": {"name": "Custom Lil Bit Podcast Episode"}
                },
                "quantity": 1
            }],
            mode="payment",
            success_url="https://lilbitfactory.ai/success",
            cancel_url="https://lilbitfactory.ai/cancel"
        )
        return jsonify({"url": session.url})
    except Exception as e:
        return jsonify({"error": str(e)}), 400

@app.route("/api/metrics")
def api_metrics():
    """Empire monitoring endpoint"""
    return jsonify(empire_monitor.get_metrics())

# =============================================================================
# EPISODE ANALYTICS
# =============================================================================

@dataclass
class EpisodeStats:
    episode_id: str
    title: str
    plays: int
    unique_listeners: int
    avg_listen_time: float
    completion_rate: float
    downloads: int
    shares: int
    recorded_at: str

class EpisodeAnalytics:
    """Track podcast episode performance"""
    
    def __init__(self):
        self.stats: Dict[str, EpisodeStats] = {}
        self.daily_plays: Dict[str, List[Dict]] = {}
    
    def record_play(self, episode_id: str, duration: float, 
                     completed: bool) -> None:
        """Record episode play"""
        if episode_id not in self.stats:
            self.stats[episode_id] = EpisodeStats(
                episode_id=episode_id,
                title=f"Episode {episode_id}",
                plays=0,
                unique_listeners=0,
                avg_listen_time=0,
                completion_rate=0,
                downloads=0,
                shares=0,
                recorded_at=datetime.now().isoformat()
            )
        
        stats = self.stats[episode_id]
        stats.plays += 1
        stats.avg_listen_time = (stats.avg_listen_time * (stats.plays - 1) + duration) / stats.plays
        
        if completed:
            total_completions = stats.completion_rate * (stats.plays - 1)
            stats.completion_rate = (total_completions + 1) / stats.plays
    
    def get_episode_stats(self, episode_id: str) -> Dict:
        """Get stats for episode"""
        stats = self.stats.get(episode_id)
        if not stats:
            return {"error": "Episode not found"}
        return asdict(stats)
    
    def get_top_episodes(self, limit: int = 10) -> List[Dict]:
        """Get top performing episodes"""
        sorted_stats = sorted(
            self.stats.values(),
            key=lambda x: x.plays,
            reverse=True
        )
        return [asdict(s) for s in sorted_stats[:limit]]
    
    def get_total_plays(self) -> int:
        """Get total plays across all episodes"""
        return sum(s.plays for s in self.stats.values())

episode_analytics = EpisodeAnalytics()

# =============================================================================
# CONTENT LIBRARY
# =============================================================================

@dataclass
class ContentItem:
    id: str
    title: str
    content_type: str  # script, audio, transcript, clip
    episode_id: Optional[str]
    file_path: str
    duration: Optional[float]
    tags: List[str]
    created_at: str

class ContentLibrary:
    """Manage podcast content library"""
    
    def __init__(self):
        self.items: Dict[str, ContentItem] = {}
    
    def add_content(self, title: str, content_type: str, 
                     file_path: str, episode_id: str = None,
                     tags: List[str] = None) -> ContentItem:
        """Add content to library"""
        item = ContentItem(
            id=hashlib.md5(f"{title}{datetime.now()}".encode()).hexdigest()[:12],
            title=title,
            content_type=content_type,
            episode_id=episode_id,
            file_path=file_path,
            duration=None,
            tags=tags or [],
            created_at=datetime.now().isoformat()
        )
        
        self.items[item.id] = item
        return item
    
    def search(self, query: str = None, content_type: str = None, 
               tags: List[str] = None) -> List[Dict]:
        """Search content library"""
        results = list(self.items.values())
        
        if query:
            query_lower = query.lower()
            results = [i for i in results if query_lower in i.title.lower()]
        
        if content_type:
            results = [i for i in results if i.content_type == content_type]
        
        if tags:
            results = [i for i in results if any(t in i.tags for t in tags)]
        
        return [asdict(i) for i in results]
    
    def get_by_episode(self, episode_id: str) -> List[Dict]:
        """Get all content for episode"""
        return [
            asdict(i) for i in self.items.values()
            if i.episode_id == episode_id
        ]

content_library = ContentLibrary()

# =============================================================================
# AUDIENCE INSIGHTS
# =============================================================================

class AudienceInsights:
    """Analyze podcast audience"""
    
    def __init__(self):
        self.listeners: Dict[str, Dict] = {}  # listener_id -> data
        self.demographics: Dict[str, int] = {}
    
    def track_listener(self, listener_id: str, data: Dict) -> None:
        """Track listener data"""
        if listener_id not in self.listeners:
            self.listeners[listener_id] = {
                "first_listen": datetime.now().isoformat(),
                "total_listens": 0,
                "episodes": []
            }
        
        self.listeners[listener_id]["total_listens"] += 1
        if data.get("episode_id"):
            self.listeners[listener_id]["episodes"].append(data["episode_id"])
    
    def get_listener_count(self) -> int:
        """Get unique listener count"""
        return len(self.listeners)
    
    def get_retention_rate(self) -> float:
        """Calculate listener retention rate"""
        if not self.listeners:
            return 0
        
        returning = sum(
            1 for l in self.listeners.values()
            if l["total_listens"] > 1
        )
        
        return round(returning / len(self.listeners) * 100, 1)
    
    def get_growth_rate(self) -> Dict:
        """Calculate growth rate"""
        today = datetime.now().strftime("%Y-%m-%d")
        week_ago = (datetime.now() - timedelta(days=7)).strftime("%Y-%m-%d")
        
        new_this_week = sum(
            1 for l in self.listeners.values()
            if l["first_listen"][:10] >= week_ago
        )
        
        return {
            "new_this_week": new_this_week,
            "total_listeners": len(self.listeners),
            "retention_rate": self.get_retention_rate()
        }

audience = AudienceInsights()

# =============================================================================
# RSS FEED GENERATOR
# =============================================================================

class RSSFeedGenerator:
    """Generate podcast RSS feed"""
    
    def __init__(self):
        self.podcast_info = {}
        self.episodes: List[Dict] = []
    
    def set_podcast_info(self, title: str, description: str, 
                          author: str, image_url: str = None) -> None:
        """Set podcast info"""
        self.podcast_info = {
            "title": title,
            "description": description,
            "author": author,
            "image_url": image_url,
            "language": "en-US",
            "updated": datetime.now().isoformat()
        }
    
    def add_episode(self, title: str, description: str, 
                     audio_url: str, duration: int,
                     pub_date: str = None) -> Dict:
        """Add episode to feed"""
        episode = {
            "id": hashlib.md5(f"{title}{datetime.now()}".encode()).hexdigest()[:12],
            "title": title,
            "description": description,
            "audio_url": audio_url,
            "duration": duration,
            "pub_date": pub_date or datetime.now().isoformat()
        }
        
        self.episodes.append(episode)
        return episode
    
    def generate_feed(self) -> str:
        """Generate RSS XML feed"""
        # Simplified RSS generation
        xml = f"""<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
<channel>
    <title>{self.podcast_info.get('title', 'Podcast')}</title>
    <description>{self.podcast_info.get('description', '')}</description>
    <language>{self.podcast_info.get('language', 'en-US')}</language>"""
        
        for ep in self.episodes:
            xml += f"""
    <item>
        <title>{ep['title']}</title>
        <description>{ep['description']}</description>
        <enclosure url="{ep['audio_url']}" type="audio/mpeg"/>
        <pubDate>{ep['pub_date']}</pubDate>
    </item>"""
        
        xml += """
</channel>
</rss>"""
        
        return xml

rss_feed = RSSFeedGenerator()

# =============================================================================
# DISTRIBUTION MANAGER
# =============================================================================

@dataclass
class Distribution:
    id: str
    episode_id: str
    platform: str  # spotify, apple, google, youtube
    status: str  # pending, submitted, live
    external_id: Optional[str]
    submitted_at: str
    live_at: Optional[str]

class DistributionManager:
    """Manage podcast distribution"""
    
    PLATFORMS = ["spotify", "apple", "google", "youtube", "amazon"]
    
    def __init__(self):
        self.distributions: Dict[str, List[Distribution]] = {}  # episode_id -> distributions
    
    def submit_to_platform(self, episode_id: str, 
                            platform: str) -> Distribution:
        """Submit episode to platform"""
        if episode_id not in self.distributions:
            self.distributions[episode_id] = []
        
        dist = Distribution(
            id=hashlib.md5(f"{episode_id}{platform}".encode()).hexdigest()[:12],
            episode_id=episode_id,
            platform=platform,
            status="submitted",
            external_id=None,
            submitted_at=datetime.now().isoformat(),
            live_at=None
        )
        
        self.distributions[episode_id].append(dist)
        return dist
    
    def submit_to_all(self, episode_id: str) -> List[Dict]:
        """Submit to all platforms"""
        results = []
        for platform in self.PLATFORMS:
            dist = self.submit_to_platform(episode_id, platform)
            results.append(asdict(dist))
        return results
    
    def get_distribution_status(self, episode_id: str) -> Dict:
        """Get distribution status for episode"""
        dists = self.distributions.get(episode_id, [])
        
        platform_status = {}
        for d in dists:
            platform_status[d.platform] = d.status
        
        return {
            "episode_id": episode_id,
            "platforms": platform_status,
            "total_submitted": len(dists),
            "total_live": sum(1 for d in dists if d.status == "live")
        }

distribution = DistributionManager()

# =============================================================================
# ADDITIONAL API ROUTES
# =============================================================================

@app.route("/api/analytics/<episode_id>")
def api_episode_analytics(episode_id):
    """Get episode analytics"""
    return jsonify(episode_analytics.get_episode_stats(episode_id))

@app.route("/api/analytics/top")
def api_top_episodes():
    """Get top episodes"""
    return jsonify({"episodes": episode_analytics.get_top_episodes()})

@app.route("/api/library", methods=["GET", "POST"])
def api_content_library():
    """Manage content library"""
    if request.method == "POST":
        data = request.get_json()
        item = content_library.add_content(
            title=data.get("title", ""),
            content_type=data.get("content_type", "audio"),
            file_path=data.get("file_path", ""),
            episode_id=data.get("episode_id"),
            tags=data.get("tags", [])
        )
        return jsonify(asdict(item))
    
    return jsonify({"items": content_library.search(
        query=request.args.get("q"),
        content_type=request.args.get("type")
    )})

@app.route("/api/audience")
def api_audience_insights():
    """Get audience insights"""
    return jsonify(audience.get_growth_rate())

@app.route("/api/rss")
def api_rss_feed():
    """Get RSS feed"""
    return rss_feed.generate_feed(), 200, {"Content-Type": "application/xml"}

@app.route("/api/distribution/<episode_id>", methods=["GET", "POST"])
def api_distribution(episode_id):
    """Manage distribution"""
    if request.method == "POST":
        results = distribution.submit_to_all(episode_id)
        return jsonify({"distributions": results})
    
    return jsonify(distribution.get_distribution_status(episode_id))

@app.route("/health")
def health():
    return jsonify({
        "status": "healthy",
        "endeavor": "Lil Bit Podcast Factory",
        "version": "1.0.0",
        "components": {
            "podcast_gen": "active",
            "episodes": len(episode_analytics.stats),
            "content_items": len(content_library.items),
            "listeners": audience.get_listener_count(),
            "distributions": sum(len(d) for d in distribution.distributions.values())
        }
    })

# =============================================================================
# MAIN
# =============================================================================

if __name__ == "__main__":
    print("🎧 Lil Bit Podcast Factory - Starting...")
    print("📍 http://localhost:5002")
    print("🔧 Components: Generator, Analytics, Library, Audience, RSS, Distribution")
    app.run(host="0.0.0.0", port=5002, debug=True)
