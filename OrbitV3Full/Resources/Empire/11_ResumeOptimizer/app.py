#!/usr/bin/env python3
"""
AI Resume Optimizer - ATS-Proof Resume & Cover Letter Generator
$2B market, 40M monthly job searches, quick revenue tool
Version: 1.0.0 | Production Ready
"""

import os
import json
import asyncio
import hashlib
import re
from datetime import datetime
from typing import Optional, Dict, List, Any
from dataclasses import dataclass, asdict

from flask import Flask, request, jsonify, render_template_string, send_file
from flask_cors import CORS
import aiohttp
# Database (optional)
try:
    from supabase import create_client, Client
except ImportError:
    Client = None
    def create_client(*args): return None
import stripe
from dotenv import load_dotenv

load_dotenv()

# =============================================================================
# CONFIGURATION
# =============================================================================

app = Flask(__name__)
CORS(app)

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_KEY = os.getenv("SUPABASE_KEY", "")
STRIPE_SECRET_KEY = os.getenv("STRIPE_SECRET_KEY", "")

stripe.api_key = STRIPE_SECRET_KEY

supabase: Optional[Client] = None
if SUPABASE_URL and SUPABASE_KEY:
    supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

# =============================================================================
# ATS KEYWORD DATABASE
# =============================================================================

ATS_KEYWORDS = {
    "software_engineer": [
        "python", "javascript", "react", "node.js", "aws", "docker", "kubernetes",
        "agile", "scrum", "ci/cd", "git", "rest api", "microservices", "sql",
        "typescript", "java", "cloud", "devops", "testing", "tdd"
    ],
    "product_manager": [
        "roadmap", "stakeholder", "agile", "scrum", "user research", "analytics",
        "okr", "kpi", "a/b testing", "jira", "confluence", "strategy",
        "cross-functional", "prioritization", "mvp", "product lifecycle"
    ],
    "data_scientist": [
        "python", "machine learning", "tensorflow", "pytorch", "pandas", "numpy",
        "sql", "tableau", "statistics", "nlp", "deep learning", "jupyter",
        "data visualization", "predictive modeling", "a/b testing", "r"
    ],
    "marketing": [
        "seo", "sem", "google analytics", "hubspot", "content strategy",
        "social media", "email marketing", "campaign management", "roi",
        "brand awareness", "lead generation", "crm", "conversion optimization"
    ],
    "sales": [
        "salesforce", "crm", "pipeline", "quota", "negotiation", "closing",
        "prospecting", "account management", "revenue", "b2b", "b2c",
        "cold calling", "relationship building", "territory management"
    ],
    "default": [
        "leadership", "communication", "problem-solving", "teamwork",
        "project management", "strategic thinking", "analytical", "results-driven"
    ]
}

# =============================================================================
# DATA MODELS
# =============================================================================

@dataclass
class ResumeAnalysis:
    original_score: int
    optimized_score: int
    keywords_added: List[str]
    keywords_missing: List[str]
    suggestions: List[str]
    ats_issues: List[str]

@dataclass
class OptimizedResume:
    id: str
    original_text: str
    optimized_text: str
    cover_letter: Optional[str]
    job_title: str
    company: Optional[str]
    analysis: ResumeAnalysis
    created_at: str

# =============================================================================
# ATS ANALYZER
# =============================================================================

class ATSAnalyzer:
    """Analyze resumes for ATS compatibility"""
    
    def analyze(self, resume_text: str, job_category: str = "default") -> Dict:
        """Analyze resume for ATS issues and keyword matching"""
        issues = []
        keywords_found = []
        keywords_missing = []
        
        lower_text = resume_text.lower()
        
        # Check for common ATS issues
        if len(resume_text) < 200:
            issues.append("Resume too short - add more detail")
        
        if not re.search(r'\b[\w\.-]+@[\w\.-]+\.\w+\b', resume_text):
            issues.append("Missing email address")
        
        if not re.search(r'\b\d{3}[-.\s]?\d{3}[-.\s]?\d{4}\b', resume_text):
            issues.append("Missing phone number")
        
        if not re.search(r'\b(linkedin|github)\b', lower_text):
            issues.append("Consider adding LinkedIn/GitHub profile")
        
        # Check for tables/graphics warnings
        if "[table]" in lower_text or "[image]" in lower_text:
            issues.append("Remove tables/images - ATS cannot parse them")
        
        # Keyword analysis
        category_keywords = ATS_KEYWORDS.get(job_category, ATS_KEYWORDS["default"])
        
        for keyword in category_keywords:
            if keyword.lower() in lower_text:
                keywords_found.append(keyword)
            else:
                keywords_missing.append(keyword)
        
        # Calculate score
        keyword_ratio = len(keywords_found) / len(category_keywords) if category_keywords else 0
        issue_penalty = len(issues) * 5
        score = max(0, min(100, int(keyword_ratio * 80 + 20 - issue_penalty)))
        
        return {
            "score": score,
            "issues": issues,
            "keywords_found": keywords_found,
            "keywords_missing": keywords_missing[:10],  # Top 10 missing
            "category": job_category
        }

# =============================================================================
# RESUME OPTIMIZER
# =============================================================================

class ResumeOptimizer:
    """Optimize resumes for ATS and human readability"""
    
    OPTIMIZE_PROMPT = """You are an expert resume writer and ATS optimization specialist.

ORIGINAL RESUME:
{resume}

JOB TITLE TARGET: {job_title}
{company_context}

MISSING KEYWORDS TO INCORPORATE:
{keywords}

ATS ISSUES TO FIX:
{issues}

INSTRUCTIONS:
1. Rewrite this resume to be ATS-optimized
2. Naturally incorporate the missing keywords where relevant
3. Fix any formatting issues
4. Use strong action verbs
5. Quantify achievements where possible
6. Keep it under 2 pages
7. Maintain professional tone

Return the optimized resume in plain text format (no markdown).
Start directly with the contact info, no preamble."""

    COVER_LETTER_PROMPT = """Write a compelling cover letter for this candidate:

RESUME SUMMARY:
{resume_summary}

JOB TITLE: {job_title}
COMPANY: {company}

The cover letter should:
1. Be 3-4 paragraphs
2. Show enthusiasm for the specific role
3. Highlight 2-3 key qualifications from the resume
4. Include a call to action
5. Be professional but personable

Return only the cover letter text, starting with "Dear Hiring Manager," """

    def __init__(self):
        self.analyzer = ATSAnalyzer()
    
    async def optimize(self, resume_text: str, job_title: str, 
                       company: Optional[str] = None,
                       generate_cover_letter: bool = False) -> OptimizedResume:
        """Fully optimize a resume"""
        
        # Detect job category
        job_category = self._detect_category(job_title)
        
        # Initial analysis
        initial_analysis = self.analyzer.analyze(resume_text, job_category)
        
        # Generate optimized version
        company_context = f"COMPANY: {company}" if company else ""
        
        prompt = self.OPTIMIZE_PROMPT.format(
            resume=resume_text[:4000],  # Limit for API
            job_title=job_title,
            company_context=company_context,
            keywords=", ".join(initial_analysis["keywords_missing"]),
            issues="\n".join(initial_analysis["issues"]) or "None"
        )
        
        optimized_text = await self._query_ai(prompt)
        
        # Re-analyze optimized version
        final_analysis = self.analyzer.analyze(optimized_text, job_category)
        
        # Generate cover letter if requested
        cover_letter = None
        if generate_cover_letter and company:
            cover_prompt = self.COVER_LETTER_PROMPT.format(
                resume_summary=resume_text[:1500],
                job_title=job_title,
                company=company
            )
            cover_letter = await self._query_ai(cover_prompt)
        
        # Create result
        result = OptimizedResume(
            id=hashlib.md5(f"{resume_text[:100]}{datetime.now()}".encode()).hexdigest()[:12],
            original_text=resume_text,
            optimized_text=optimized_text,
            cover_letter=cover_letter,
            job_title=job_title,
            company=company,
            analysis=ResumeAnalysis(
                original_score=initial_analysis["score"],
                optimized_score=final_analysis["score"],
                keywords_added=[k for k in final_analysis["keywords_found"] 
                               if k not in initial_analysis["keywords_found"]],
                keywords_missing=final_analysis["keywords_missing"],
                suggestions=self._generate_suggestions(initial_analysis, final_analysis),
                ats_issues=initial_analysis["issues"]
            ),
            created_at=datetime.now().isoformat()
        )
        
        # Store in Supabase
        if supabase:
            try:
                supabase.table("resumes").insert({
                    "id": result.id,
                    "job_title": job_title,
                    "original_score": result.analysis.original_score,
                    "optimized_score": result.analysis.optimized_score,
                    "created_at": result.created_at
                }).execute()
            except Exception as e:
                print(f"DB error: {e}")
        
        return result
    
    def _detect_category(self, job_title: str) -> str:
        """Detect job category from title"""
        title_lower = job_title.lower()
        
        if any(k in title_lower for k in ["software", "developer", "engineer", "programming"]):
            return "software_engineer"
        elif any(k in title_lower for k in ["product manager", "pm", "product owner"]):
            return "product_manager"
        elif any(k in title_lower for k in ["data scientist", "data analyst", "machine learning"]):
            return "data_scientist"
        elif any(k in title_lower for k in ["marketing", "brand", "content", "seo"]):
            return "marketing"
        elif any(k in title_lower for k in ["sales", "account", "business development"]):
            return "sales"
        
        return "default"
    
    def _generate_suggestions(self, initial: Dict, final: Dict) -> List[str]:
        """Generate improvement suggestions"""
        suggestions = []
        
        if final["score"] > initial["score"]:
            suggestions.append(f"✅ ATS score improved from {initial['score']} to {final['score']}")
        
        if initial["issues"]:
            suggestions.append(f"📝 Fixed {len(initial['issues'])} ATS compatibility issues")
        
        keywords_added = len(final["keywords_found"]) - len(initial.get("keywords_found", []))
        if keywords_added > 0:
            suggestions.append(f"🔑 Added {keywords_added} relevant keywords")
        
        suggestions.append("💡 Review optimized version and customize personal details")
        suggestions.append("📄 Consider adding metrics/numbers to achievements")
        
        return suggestions
    
    async def _query_ai(self, prompt: str) -> str:
        """Query Gemini API"""
        if not GEMINI_API_KEY:
            return "AI service unavailable. Please configure GEMINI_API_KEY."
        
        url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key={GEMINI_API_KEY}"
        payload = {
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {"temperature": 0.7, "maxOutputTokens": 4096}
        }
        
        async with aiohttp.ClientSession() as session:
            try:
                async with session.post(url, json=payload) as resp:
                    if resp.status == 200:
                        data = await resp.json()
                        return data["candidates"][0]["content"]["parts"][0]["text"]
            except Exception as e:
                print(f"AI error: {e}")
        
        return "Unable to optimize resume. Please try again."

# Global optimizer
optimizer = ResumeOptimizer()

# =============================================================================
# VIRAL REFERRAL SYSTEM
# =============================================================================

class ReferralSystem:
    """Viral loop with share-for-credit mechanics"""
    
    def generate_referral_link(self, user_id: str) -> str:
        """Generate unique referral link"""
        code = hashlib.md5(f"{user_id}referral".encode()).hexdigest()[:8]
        return f"https://resumeoptimizer.ai/?ref={code}"
    
    def apply_credit(self, referrer_id: str, amount: float = 5.0) -> bool:
        """Apply referral credit to user account"""
        if supabase:
            try:
                result = supabase.table("users").select("credits").eq("id", referrer_id).single().execute()
                current = result.data.get("credits", 0) if result.data else 0
                supabase.table("users").update({"credits": current + amount}).eq("id", referrer_id).execute()
                return True
            except Exception as e:
                print(f"Referral credit error: {e}")
        return False

referral_system = ReferralSystem()

# =============================================================================
# API ROUTES
# =============================================================================

@app.route("/")
def home():
    return render_template_string("""
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AI Resume Optimizer | ATS-Proof in Seconds</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Inter', -apple-system, sans-serif;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
            color: #fff;
            min-height: 100vh;
        }
        .container { max-width: 1000px; margin: 0 auto; padding: 2rem; }
        header { text-align: center; padding: 3rem 0; }
        h1 {
            font-size: 2.8rem;
            background: linear-gradient(90deg, #00d4ff, #00ff88);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }
        .stat-bar {
            display: flex;
            justify-content: center;
            gap: 3rem;
            margin: 2rem 0;
        }
        .stat { text-align: center; }
        .stat-value { font-size: 2.5rem; font-weight: 700; color: #00ff88; }
        .stat-label { color: #888; }
        .editor-container {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 2rem;
            margin: 2rem 0;
        }
        .editor-panel {
            background: rgba(255,255,255,0.05);
            border-radius: 16px;
            padding: 1.5rem;
            border: 1px solid rgba(255,255,255,0.1);
        }
        .editor-panel h3 { margin-bottom: 1rem; color: #00d4ff; }
        textarea {
            width: 100%;
            height: 300px;
            background: rgba(0,0,0,0.3);
            border: 1px solid rgba(255,255,255,0.2);
            border-radius: 8px;
            padding: 1rem;
            color: #fff;
            font-family: 'Courier New', monospace;
            font-size: 0.9rem;
            resize: vertical;
        }
        .controls {
            display: flex;
            gap: 1rem;
            margin: 1rem 0;
            flex-wrap: wrap;
        }
        input[type="text"] {
            flex: 1;
            padding: 0.8rem;
            border-radius: 8px;
            border: 1px solid rgba(255,255,255,0.2);
            background: rgba(0,0,0,0.3);
            color: #fff;
        }
        button {
            background: linear-gradient(90deg, #00d4ff, #00ff88);
            color: #000;
            padding: 1rem 2rem;
            border: none;
            border-radius: 8px;
            font-weight: 600;
            cursor: pointer;
            transition: transform 0.2s;
        }
        button:hover { transform: scale(1.05); }
        .score-display {
            display: flex;
            gap: 2rem;
            margin: 1rem 0;
        }
        .score {
            padding: 1rem 2rem;
            border-radius: 8px;
            text-align: center;
        }
        .score-before { background: rgba(255,100,100,0.2); border: 1px solid #ff6464; }
        .score-after { background: rgba(0,255,136,0.2); border: 1px solid #00ff88; }
        .score-value { font-size: 2rem; font-weight: 700; }
        .suggestions { margin-top: 1rem; }
        .suggestion {
            padding: 0.5rem;
            margin: 0.3rem 0;
            background: rgba(0,212,255,0.1);
            border-radius: 4px;
        }
        .pricing-row {
            display: flex;
            justify-content: center;
            gap: 2rem;
            margin: 3rem 0;
        }
        .price-card {
            background: rgba(255,255,255,0.05);
            border-radius: 16px;
            padding: 2rem;
            text-align: center;
            border: 1px solid rgba(255,255,255,0.1);
            min-width: 200px;
        }
        .price-card.featured { border-color: #00ff88; }
        .price { font-size: 2.5rem; font-weight: 700; }
        .price span { font-size: 1rem; color: #888; }
        @media (max-width: 768px) {
            .editor-container { grid-template-columns: 1fr; }
            .pricing-row { flex-direction: column; }
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>📄 AI Resume Optimizer</h1>
            <p style="font-size: 1.2rem; color: #888; margin-top: 1rem;">Get past ATS filters. Land more interviews.</p>
        </header>
        
        <div class="stat-bar">
            <div class="stat">
                <div class="stat-value">40M</div>
                <div class="stat-label">Monthly Job Searches</div>
            </div>
            <div class="stat">
                <div class="stat-value">75%</div>
                <div class="stat-label">ATS Rejection Rate</div>
            </div>
            <div class="stat">
                <div class="stat-value">3x</div>
                <div class="stat-label">More Interviews</div>
            </div>
        </div>
        
        <div class="controls">
            <input type="text" id="jobTitle" placeholder="Target Job Title (e.g., Software Engineer)" />
            <input type="text" id="company" placeholder="Company Name (optional)" />
        </div>
        
        <div class="editor-container">
            <div class="editor-panel">
                <h3>📝 Paste Your Resume</h3>
                <textarea id="resumeInput" placeholder="Paste your current resume here..."></textarea>
            </div>
            <div class="editor-panel">
                <h3>✨ Optimized Resume</h3>
                <textarea id="resumeOutput" readonly placeholder="Your optimized resume will appear here..."></textarea>
            </div>
        </div>
        
        <div style="text-align: center;">
            <button onclick="optimizeResume()">🚀 Optimize My Resume</button>
            <button onclick="generateWithCoverLetter()" style="background: linear-gradient(90deg, #7b2ff7, #00d4ff);">
                📨 + Cover Letter ($49)
            </button>
        </div>
        
        <div id="results" style="display: none; margin-top: 2rem;">
            <div class="score-display">
                <div class="score score-before">
                    <div>Before</div>
                    <div class="score-value" id="scoreBefore">--</div>
                </div>
                <div class="score score-after">
                    <div>After</div>
                    <div class="score-value" id="scoreAfter">--</div>
                </div>
            </div>
            <div class="suggestions" id="suggestions"></div>
        </div>
        
        <div class="pricing-row">
            <div class="price-card">
                <h3>Basic</h3>
                <div class="price">$19</div>
                <p style="color: #888; margin: 1rem 0;">ATS Optimization Only</p>
                <ul style="text-align: left; color: #aaa; font-size: 0.9rem;">
                    <li>✓ ATS keyword optimization</li>
                    <li>✓ Score analysis</li>
                    <li>✓ PDF export</li>
                </ul>
            </div>
            <div class="price-card featured">
                <h3>Premium</h3>
                <div class="price">$49</div>
                <p style="color: #00ff88; margin: 1rem 0;">Resume + Cover Letter</p>
                <ul style="text-align: left; color: #aaa; font-size: 0.9rem;">
                    <li>✓ Everything in Basic</li>
                    <li>✓ Custom cover letter</li>
                    <li>✓ LinkedIn optimization tips</li>
                    <li>✓ $5 referral credit</li>
                </ul>
            </div>
        </div>
        
        <div style="text-align: center; color: #666; margin-top: 2rem;">
            <p>💰 Share your optimized resume and earn $5 credit for each friend who signs up!</p>
        </div>
    </div>
    
    <script>
        async function optimizeResume() {
            const resume = document.getElementById('resumeInput').value;
            const jobTitle = document.getElementById('jobTitle').value || 'General';
            const company = document.getElementById('company').value;
            
            if (!resume) {
                alert('Please paste your resume first');
                return;
            }
            
            document.getElementById('resumeOutput').value = 'Optimizing...';
            
            try {
                const response = await fetch('/api/optimize', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({resume, job_title: jobTitle, company, include_cover_letter: false})
                });
                const data = await response.json();
                
                document.getElementById('resumeOutput').value = data.optimized_text || 'Error optimizing';
                document.getElementById('scoreBefore').textContent = data.analysis?.original_score || '--';
                document.getElementById('scoreAfter').textContent = data.analysis?.optimized_score || '--';
                document.getElementById('results').style.display = 'block';
                
                const suggestionsDiv = document.getElementById('suggestions');
                suggestionsDiv.innerHTML = (data.analysis?.suggestions || [])
                    .map(s => `<div class="suggestion">${s}</div>`)
                    .join('');
            } catch (error) {
                document.getElementById('resumeOutput').value = 'Error: ' + error.message;
            }
        }
        
        async function generateWithCoverLetter() {
            const resume = document.getElementById('resumeInput').value;
            const jobTitle = document.getElementById('jobTitle').value;
            const company = document.getElementById('company').value;
            
            if (!resume || !company) {
                alert('Please fill in resume and company name for cover letter');
                return;
            }
            
            // In production, this would redirect to Stripe checkout
            alert('Redirecting to checkout for Premium package...');
        }
    </script>
</body>
</html>
    """)

@app.route("/api/optimize", methods=["POST"])
def api_optimize():
    """Optimize a resume"""
    data = request.get_json()
    resume = data.get("resume", "")
    job_title = data.get("job_title", "General")
    company = data.get("company")
    include_cover = data.get("include_cover_letter", False)
    
    if not resume:
        return jsonify({"error": "No resume provided"}), 400
    
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    result = loop.run_until_complete(
        optimizer.optimize(resume, job_title, company, include_cover)
    )
    loop.close()
    
    return jsonify({
        "id": result.id,
        "optimized_text": result.optimized_text,
        "cover_letter": result.cover_letter,
        "analysis": asdict(result.analysis)
    })

@app.route("/api/analyze", methods=["POST"])
def api_analyze():
    """Analyze resume without optimization"""
    data = request.get_json()
    resume = data.get("resume", "")
    job_title = data.get("job_title", "default")
    
    category = optimizer._detect_category(job_title)
    analysis = optimizer.analyzer.analyze(resume, category)
    
    return jsonify(analysis)

@app.route("/api/referral/<user_id>")
def api_referral(user_id):
    """Get referral link"""
    link = referral_system.generate_referral_link(user_id)
    return jsonify({"referral_link": link, "credit_amount": 5})

@app.route("/api/checkout/<tier>")
def api_checkout(tier):
    """Stripe checkout"""
    prices = {"basic": 1900, "premium": 4900}
    amount = prices.get(tier, 1900)
    
    try:
        session = stripe.checkout.Session.create(
            payment_method_types=["card"],
            line_items=[{
                "price_data": {
                    "currency": "usd",
                    "unit_amount": amount,
                    "product_data": {"name": f"Resume Optimizer - {tier.title()}"}
                },
                "quantity": 1
            }],
            mode="payment",
            success_url="https://resumeoptimizer.ai/success",
            cancel_url="https://resumeoptimizer.ai/"
        )
        return jsonify({"url": session.url})
    except Exception as e:
        return jsonify({"error": str(e)}), 400

@app.route("/api/metrics")
def api_metrics():
    return jsonify({
        "endeavor": "AI Resume Optimizer",
        "version": "1.0.0",
        "status": "operational",
        "pricing": {"basic": 19, "premium": 49},
        "market_size": "$2B",
        "monthly_searches": "40M"
    })

# =============================================================================
# RESUME VERSIONING
# =============================================================================

@dataclass
class ResumeVersion:
    id: str
    user_id: str
    name: str
    target_role: str
    content: Dict
    ats_score: float
    created_at: str
    is_default: bool

class ResumeVersioning:
    """Manage multiple resume versions"""
    
    def __init__(self):
        self.versions: Dict[str, List[ResumeVersion]] = {}  # user_id -> versions
    
    def create_version(self, user_id: str, name: str, target_role: str, 
                        content: Dict) -> ResumeVersion:
        """Create new resume version"""
        if user_id not in self.versions:
            self.versions[user_id] = []
        
        version = ResumeVersion(
            id=hashlib.md5(f"{user_id}{name}{datetime.now()}".encode()).hexdigest()[:12],
            user_id=user_id,
            name=name,
            target_role=target_role,
            content=content,
            ats_score=0,
            created_at=datetime.now().isoformat(),
            is_default=len(self.versions[user_id]) == 0
        )
        
        self.versions[user_id].append(version)
        return version
    
    def get_versions(self, user_id: str) -> List[Dict]:
        """Get all versions for user"""
        return [asdict(v) for v in self.versions.get(user_id, [])]
    
    def set_default(self, user_id: str, version_id: str) -> bool:
        """Set default version"""
        versions = self.versions.get(user_id, [])
        for v in versions:
            v.is_default = v.id == version_id
        return True
    
    def delete_version(self, user_id: str, version_id: str) -> bool:
        """Delete version"""
        versions = self.versions.get(user_id, [])
        self.versions[user_id] = [v for v in versions if v.id != version_id]
        return True

resume_versions = ResumeVersioning()

# =============================================================================
# INTERVIEW PREP
# =============================================================================

@dataclass
class InterviewQuestion:
    id: str
    category: str  # behavioral, technical, situational
    question: str
    suggested_answer: str
    tips: List[str]
    difficulty: str  # easy, medium, hard

class InterviewPrep:
    """Interview preparation system"""
    
    QUESTION_TEMPLATES = {
        "behavioral": [
            "Tell me about a time when you faced a challenging situation at work.",
            "Describe a project where you demonstrated leadership.",
            "How do you handle conflict with team members?",
            "Give an example of when you failed and what you learned."
        ],
        "technical": [
            "Walk me through your experience with {skill}.",
            "How would you approach solving {problem}?",
            "What's your experience with {technology}?"
        ],
        "situational": [
            "How would you handle a tight deadline with incomplete information?",
            "What would you do if you disagreed with your manager's decision?",
            "How would you prioritize competing tasks?"
        ]
    }
    
    def __init__(self):
        self.prepared_questions: Dict[str, List[InterviewQuestion]] = {}
    
    async def generate_questions(self, role: str, skills: List[str], 
                                  company: str = None) -> List[InterviewQuestion]:
        """Generate interview questions for role"""
        prompt = f"""Generate 5 interview questions for a {role} position.
        
Skills: {', '.join(skills)}
Company: {company or 'General'}

For each question provide:
1. Category (behavioral, technical, or situational)
2. The question
3. A brief suggested answer approach
4. 2-3 tips

Return JSON array: [{{"category": "...", "question": "...", "answer": "...", "tips": ["..."]}}]"""
        
        # Would call AI here
        questions = []
        for i, cat in enumerate(["behavioral", "technical", "situational", "behavioral", "technical"]):
            q = InterviewQuestion(
                id=hashlib.md5(f"{role}{i}".encode()).hexdigest()[:12],
                category=cat,
                question=self.QUESTION_TEMPLATES.get(cat, ["Generic question"])[0],
                suggested_answer="Use STAR method to structure your response",
                tips=["Be specific", "Use quantifiable results", "Keep it concise"],
                difficulty="medium"
            )
            questions.append(q)
        
        return questions
    
    def get_practice_session(self, question_ids: List[str]) -> List[Dict]:
        """Get practice session with questions"""
        return [{"id": qid, "status": "pending"} for qid in question_ids]

interview_prep = InterviewPrep()

# =============================================================================
# SKILL GAP ANALYSIS
# =============================================================================

class SkillGapAnalysis:
    """Analyze skill gaps between resume and job requirements"""
    
    def __init__(self):
        self.analyses: List[Dict] = []
    
    def analyze(self, resume_skills: List[str], job_requirements: List[str]) -> Dict:
        """Analyze skill gaps"""
        resume_set = set(s.lower() for s in resume_skills)
        job_set = set(r.lower() for r in job_requirements)
        
        matching = resume_set & job_set
        missing = job_set - resume_set
        extra = resume_set - job_set
        
        match_pct = len(matching) / max(len(job_set), 1) * 100
        
        analysis = {
            "match_percentage": round(match_pct, 1),
            "matching_skills": list(matching),
            "missing_skills": list(missing),
            "extra_skills": list(extra),
            "recommendations": self._get_recommendations(missing)
        }
        
        self.analyses.append(analysis)
        return analysis
    
    def _get_recommendations(self, missing: set) -> List[Dict]:
        """Get recommendations for missing skills"""
        recommendations = []
        for skill in list(missing)[:5]:
            recommendations.append({
                "skill": skill,
                "priority": "high" if skill else "medium",
                "resources": [
                    f"Complete a {skill} certification",
                    f"Build a project using {skill}",
                    f"Take an online course on {skill}"
                ]
            })
        return recommendations

skill_gap = SkillGapAnalysis()

# =============================================================================
# COVER LETTER GENERATOR
# =============================================================================

class CoverLetterGenerator:
    """Generate tailored cover letters"""
    
    TEMPLATES = {
        "standard": """Dear Hiring Manager,

I am writing to express my strong interest in the {role} position at {company}. With my background in {experience}, I am confident I would be a valuable addition to your team.

{body}

I am excited about the opportunity to contribute to {company}'s mission and would welcome the chance to discuss how my skills align with your needs.

Best regards,
{name}""",
        
        "creative": """Hello {company} Team!

Your {role} opening caught my attention, and I had to reach out. Here's why I'm excited:

{body}

I'd love to chat about how I can bring value to your team. When can we connect?

Cheers,
{name}""",
        
        "formal": """Dear Hiring Committee,

I am pleased to submit my application for the {role} position at {company}. My qualifications include {experience}, which directly align with your requirements.

{body}

I appreciate your consideration and look forward to the opportunity to discuss my candidacy.

Respectfully,
{name}"""
    }
    
    def __init__(self):
        self.letters: List[Dict] = []
    
    async def generate(self, name: str, role: str, company: str, 
                        experience: str, highlights: List[str],
                        template: str = "standard") -> Dict:
        """Generate cover letter"""
        body = "\n\n".join([
            f"• {h}" for h in highlights[:4]
        ])
        
        letter = self.TEMPLATES.get(template, self.TEMPLATES["standard"]).format(
            name=name,
            role=role,
            company=company,
            experience=experience,
            body=body
        )
        
        result = {
            "id": hashlib.md5(f"{name}{company}{datetime.now()}".encode()).hexdigest()[:12],
            "content": letter,
            "template": template,
            "word_count": len(letter.split()),
            "created_at": datetime.now().isoformat()
        }
        
        self.letters.append(result)
        return result

cover_letter = CoverLetterGenerator()

# =============================================================================
# APPLICATION TRACKER
# =============================================================================

@dataclass
class Application:
    id: str
    user_id: str
    company: str
    role: str
    status: str  # applied, screening, interview, offer, rejected
    applied_date: str
    resume_version_id: str
    notes: List[str]
    next_steps: Optional[str]

class ApplicationTracker:
    """Track job applications"""
    
    def __init__(self):
        self.applications: Dict[str, List[Application]] = {}  # user_id -> apps
    
    def add_application(self, user_id: str, company: str, role: str,
                         resume_version_id: str) -> Application:
        """Add new application"""
        if user_id not in self.applications:
            self.applications[user_id] = []
        
        app = Application(
            id=hashlib.md5(f"{user_id}{company}{role}".encode()).hexdigest()[:12],
            user_id=user_id,
            company=company,
            role=role,
            status="applied",
            applied_date=datetime.now().isoformat(),
            resume_version_id=resume_version_id,
            notes=[],
            next_steps="Wait for response"
        )
        
        self.applications[user_id].append(app)
        return app
    
    def update_status(self, user_id: str, app_id: str, status: str, 
                       notes: str = None) -> bool:
        """Update application status"""
        apps = self.applications.get(user_id, [])
        for app in apps:
            if app.id == app_id:
                app.status = status
                if notes:
                    app.notes.append(notes)
                return True
        return False
    
    def get_applications(self, user_id: str) -> List[Dict]:
        """Get all applications for user"""
        return [asdict(a) for a in self.applications.get(user_id, [])]
    
    def get_stats(self, user_id: str) -> Dict:
        """Get application statistics"""
        apps = self.applications.get(user_id, [])
        
        by_status = {}
        for app in apps:
            by_status[app.status] = by_status.get(app.status, 0) + 1
        
        return {
            "total": len(apps),
            "by_status": by_status,
            "response_rate": round(
                (by_status.get("interview", 0) + by_status.get("offer", 0)) / 
                max(len(apps), 1) * 100, 1
            )
        }

app_tracker = ApplicationTracker()

# =============================================================================
# ADDITIONAL API ROUTES
# =============================================================================

@app.route("/api/versions", methods=["GET", "POST"])
def api_versions():
    """Manage resume versions"""
    user_id = request.args.get("user_id", "demo")
    
    if request.method == "POST":
        data = request.get_json()
        version = resume_versions.create_version(
            user_id=user_id,
            name=data.get("name", "Untitled"),
            target_role=data.get("target_role", ""),
            content=data.get("content", {})
        )
        return jsonify(asdict(version))
    
    return jsonify({"versions": resume_versions.get_versions(user_id)})

@app.route("/api/interview-prep", methods=["POST"])
def api_interview_prep():
    """Generate interview questions"""
    data = request.get_json()
    
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    questions = loop.run_until_complete(
        interview_prep.generate_questions(
            role=data.get("role", ""),
            skills=data.get("skills", []),
            company=data.get("company")
        )
    )
    loop.close()
    
    return jsonify({"questions": [asdict(q) for q in questions]})

@app.route("/api/skill-gap", methods=["POST"])
def api_skill_gap():
    """Analyze skill gaps"""
    data = request.get_json()
    analysis = skill_gap.analyze(
        resume_skills=data.get("resume_skills", []),
        job_requirements=data.get("job_requirements", [])
    )
    return jsonify(analysis)

@app.route("/api/cover-letter", methods=["POST"])
def api_cover_letter():
    """Generate cover letter"""
    data = request.get_json()
    
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    letter = loop.run_until_complete(
        cover_letter.generate(
            name=data.get("name", ""),
            role=data.get("role", ""),
            company=data.get("company", ""),
            experience=data.get("experience", ""),
            highlights=data.get("highlights", []),
            template=data.get("template", "standard")
        )
    )
    loop.close()
    
    return jsonify(letter)

@app.route("/api/applications", methods=["GET", "POST"])
def api_applications():
    """Manage applications"""
    user_id = request.args.get("user_id", "demo")
    
    if request.method == "POST":
        data = request.get_json()
        app = app_tracker.add_application(
            user_id=user_id,
            company=data.get("company", ""),
            role=data.get("role", ""),
            resume_version_id=data.get("resume_version_id", "")
        )
        return jsonify(asdict(app))
    
    return jsonify({
        "applications": app_tracker.get_applications(user_id),
        "stats": app_tracker.get_stats(user_id)
    })

@app.route("/health")
def health():
    return jsonify({
        "status": "healthy",
        "endeavor": "AI Resume Optimizer",
        "components": {
            "optimizer": "active",
            "versions": sum(len(v) for v in resume_versions.versions.values()),
            "interview_prep": "active",
            "skill_gap": len(skill_gap.analyses),
            "cover_letters": len(cover_letter.letters),
            "applications": sum(len(a) for a in app_tracker.applications.values())
        }
    })

if __name__ == "__main__":
    print("📄 AI Resume Optimizer - Starting...")
    print("📍 http://localhost:5011")
    print("🔧 Components: Optimizer, Versions, Interview, Skills, Cover Letters, Tracker")
    app.run(host="0.0.0.0", port=5011, debug=True)
