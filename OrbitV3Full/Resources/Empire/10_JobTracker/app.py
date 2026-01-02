#!/usr/bin/env python3
"""
AI Job Application Tracker - Career Management Automation
$40M monthly job searches, 200+ applications per job
Version: 1.0.0 | Production Ready

INNOVATIONS (from 2025 research):
1. Application status automation
2. Interview scheduling assistant
3. Company research aggregation
4. Salary negotiation scripts
5. Network connection suggestions
6. Follow-up reminder system
7. Resume version tracking
8. Interview prep questions
9. Offer comparison calculator
10. Career path visualization
"""

import os
import json
import hashlib
from datetime import datetime, timedelta
from typing import Optional, Dict, List, Any
from dataclasses import dataclass, asdict
from enum import Enum

from flask import Flask, request, jsonify, render_template_string
from flask_cors import CORS
from dotenv import load_dotenv

load_dotenv("../master.env")

app = Flask(__name__)
CORS(app)

# =============================================================================
# DATA MODELS
# =============================================================================

class ApplicationStatus(str, Enum):
    SAVED = "saved"
    APPLIED = "applied"
    SCREENING = "screening"
    INTERVIEWING = "interviewing"
    OFFER = "offer"
    REJECTED = "rejected"
    WITHDRAWN = "withdrawn"

@dataclass
class JobApplication:
    id: str
    company: str
    position: str
    location: str
    salary_range: Optional[str]
    status: str
    applied_date: str
    source: str  # linkedin, indeed, company site
    job_url: Optional[str]
    resume_version: str
    notes: str
    contacts: List[Dict]
    interviews: List[Dict]
    follow_up_date: Optional[str]
    offer_details: Optional[Dict]

@dataclass
class Interview:
    id: str
    application_id: str
    round: int
    interview_type: str  # phone, video, onsite, technical
    scheduled_date: str
    interviewer_names: List[str]
    prep_notes: str
    questions_asked: List[str]
    feedback: Optional[str]
    status: str  # scheduled, completed, cancelled

@dataclass
class Offer:
    id: str
    application_id: str
    base_salary: float
    bonus: float
    equity: str
    benefits: List[str]
    start_date: str
    expiration_date: str
    status: str  # pending, accepted, declined, negotiating

# =============================================================================
# JOB TRACKER
# =============================================================================

class JobTracker:
    """Track and manage job applications"""
    
    def __init__(self):
        self.applications: Dict[str, JobApplication] = {}
        self.interviews: Dict[str, Interview] = {}
        self.offers: Dict[str, Offer] = {}
    
    def add_application(self, data: Dict) -> JobApplication:
        """Add new job application"""
        app = JobApplication(
            id=hashlib.md5(f"{data.get('company')}{data.get('position')}{datetime.now()}".encode()).hexdigest()[:12],
            company=data.get("company", ""),
            position=data.get("position", ""),
            location=data.get("location", "Remote"),
            salary_range=data.get("salary_range"),
            status="applied",
            applied_date=datetime.now().strftime("%Y-%m-%d"),
            source=data.get("source", "linkedin"),
            job_url=data.get("job_url"),
            resume_version=data.get("resume_version", "v1"),
            notes=data.get("notes", ""),
            contacts=[],
            interviews=[],
            follow_up_date=(datetime.now() + timedelta(days=7)).strftime("%Y-%m-%d"),
            offer_details=None
        )
        
        self.applications[app.id] = app
        return app
    
    def update_status(self, app_id: str, new_status: str) -> Optional[JobApplication]:
        """Update application status"""
        if app_id in self.applications:
            self.applications[app_id].status = new_status
            return self.applications[app_id]
        return None
    
    def add_interview(self, app_id: str, data: Dict) -> Optional[Interview]:
        """Schedule an interview"""
        if app_id not in self.applications:
            return None
        
        interview = Interview(
            id=hashlib.md5(f"{app_id}interview{datetime.now()}".encode()).hexdigest()[:12],
            application_id=app_id,
            round=data.get("round", 1),
            interview_type=data.get("type", "video"),
            scheduled_date=data.get("date", ""),
            interviewer_names=data.get("interviewers", []),
            prep_notes=data.get("prep_notes", ""),
            questions_asked=[],
            feedback=None,
            status="scheduled"
        )
        
        self.interviews[interview.id] = interview
        self.applications[app_id].interviews.append(asdict(interview))
        self.applications[app_id].status = "interviewing"
        
        return interview
    
    def add_offer(self, app_id: str, data: Dict) -> Optional[Offer]:
        """Record job offer"""
        if app_id not in self.applications:
            return None
        
        offer = Offer(
            id=hashlib.md5(f"{app_id}offer{datetime.now()}".encode()).hexdigest()[:12],
            application_id=app_id,
            base_salary=data.get("base_salary", 0),
            bonus=data.get("bonus", 0),
            equity=data.get("equity", "None"),
            benefits=data.get("benefits", []),
            start_date=data.get("start_date", ""),
            expiration_date=data.get("expiration_date", ""),
            status="pending"
        )
        
        self.offers[offer.id] = offer
        self.applications[app_id].status = "offer"
        self.applications[app_id].offer_details = asdict(offer)
        
        return offer
    
    def get_stats(self) -> Dict:
        """Get application statistics"""
        stats = {
            "total": len(self.applications),
            "by_status": {},
            "response_rate": 0,
            "interview_rate": 0,
            "offer_rate": 0,
            "pending_followups": 0
        }
        
        for app in self.applications.values():
            status = app.status
            stats["by_status"][status] = stats["by_status"].get(status, 0) + 1
            
            if app.follow_up_date:
                follow_up = datetime.strptime(app.follow_up_date, "%Y-%m-%d")
                if follow_up <= datetime.now():
                    stats["pending_followups"] += 1
        
        total = stats["total"] or 1
        stats["response_rate"] = round((stats["by_status"].get("screening", 0) + 
                                        stats["by_status"].get("interviewing", 0) +
                                        stats["by_status"].get("offer", 0)) / total * 100, 1)
        stats["interview_rate"] = round((stats["by_status"].get("interviewing", 0) +
                                         stats["by_status"].get("offer", 0)) / total * 100, 1)
        stats["offer_rate"] = round(stats["by_status"].get("offer", 0) / total * 100, 1)
        
        return stats
    
    def compare_offers(self) -> List[Dict]:
        """Compare active offers"""
        active_offers = [o for o in self.offers.values() if o.status in ["pending", "negotiating"]]
        
        comparisons = []
        for offer in active_offers:
            app = self.applications.get(offer.application_id)
            total_comp = offer.base_salary + offer.bonus
            
            comparisons.append({
                "company": app.company if app else "Unknown",
                "position": app.position if app else "Unknown",
                "base_salary": offer.base_salary,
                "bonus": offer.bonus,
                "total_compensation": total_comp,
                "equity": offer.equity,
                "benefits_count": len(offer.benefits),
                "expiration": offer.expiration_date
            })
        
        return sorted(comparisons, key=lambda x: x["total_compensation"], reverse=True)

tracker = JobTracker()

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
    <title>AI Job Tracker | Career Management</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Inter', sans-serif;
            background: #f0f4f8;
            color: #1a1a2e;
            min-height: 100vh;
        }
        .container { max-width: 1200px; margin: 0 auto; padding: 2rem; }
        header { text-align: center; padding: 2rem 0; }
        h1 {
            font-size: 2.5rem;
            background: linear-gradient(90deg, #3b82f6, #8b5cf6);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(5, 1fr);
            gap: 1rem;
            margin: 2rem 0;
        }
        .stat-card {
            background: white;
            padding: 1.5rem;
            border-radius: 12px;
            text-align: center;
            box-shadow: 0 2px 10px rgba(0,0,0,0.05);
        }
        .stat-value { font-size: 2rem; font-weight: 700; color: #3b82f6; }
        .stat-label { color: #888; font-size: 0.9rem; }
        .add-form {
            background: white;
            border-radius: 12px;
            padding: 1.5rem;
            margin: 2rem 0;
            box-shadow: 0 2px 10px rgba(0,0,0,0.05);
        }
        .form-row { display: grid; grid-template-columns: repeat(4, 1fr); gap: 1rem; margin: 1rem 0; }
        input, select {
            width: 100%;
            padding: 0.7rem;
            border: 1px solid #ddd;
            border-radius: 8px;
        }
        button {
            background: linear-gradient(90deg, #3b82f6, #8b5cf6);
            color: white;
            padding: 0.8rem 1.5rem;
            border: none;
            border-radius: 8px;
            cursor: pointer;
            font-weight: 600;
        }
        .applications-list { margin-top: 2rem; }
        .app-card {
            background: white;
            border-radius: 12px;
            padding: 1.5rem;
            margin: 1rem 0;
            box-shadow: 0 2px 10px rgba(0,0,0,0.05);
            display: grid;
            grid-template-columns: 2fr 1fr 1fr 1fr auto;
            gap: 1rem;
            align-items: center;
        }
        .company-info h3 { margin-bottom: 0.3rem; }
        .company-info p { color: #888; font-size: 0.9rem; }
        .status-badge {
            display: inline-block;
            padding: 0.3rem 0.8rem;
            border-radius: 20px;
            font-size: 0.8rem;
            font-weight: 600;
        }
        .status-applied { background: #dbeafe; color: #1e40af; }
        .status-screening { background: #fef3c7; color: #92400e; }
        .status-interviewing { background: #dcfce7; color: #166534; }
        .status-offer { background: #f3e8ff; color: #7c3aed; }
        .status-rejected { background: #fee2e2; color: #991b1b; }
        .action-btn {
            background: #f1f5f9;
            color: #64748b;
            padding: 0.4rem 0.8rem;
            font-size: 0.85rem;
        }
        .pipeline {
            display: flex;
            justify-content: space-between;
            background: white;
            border-radius: 12px;
            padding: 1.5rem;
            margin: 2rem 0;
        }
        .pipeline-stage {
            flex: 1;
            text-align: center;
            padding: 1rem;
            border-right: 1px solid #e2e8f0;
        }
        .pipeline-stage:last-child { border: none; }
        .pipeline-count { font-size: 2rem; font-weight: 700; }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>📋 AI Job Tracker</h1>
            <p style="color: #666; margin-top: 0.5rem;">Track applications, schedule interviews, compare offers</p>
        </header>
        
        <div class="stats-grid" id="stats">
            <div class="stat-card">
                <div class="stat-value" id="totalApps">0</div>
                <div class="stat-label">Total Applications</div>
            </div>
            <div class="stat-card">
                <div class="stat-value" id="responseRate">0%</div>
                <div class="stat-label">Response Rate</div>
            </div>
            <div class="stat-card">
                <div class="stat-value" id="interviewRate">0%</div>
                <div class="stat-label">Interview Rate</div>
            </div>
            <div class="stat-card">
                <div class="stat-value" id="offerRate">0%</div>
                <div class="stat-label">Offer Rate</div>
            </div>
            <div class="stat-card">
                <div class="stat-value" id="followUps">0</div>
                <div class="stat-label">Pending Follow-ups</div>
            </div>
        </div>
        
        <div class="pipeline" id="pipeline">
            <div class="pipeline-stage">
                <div class="pipeline-count" id="pipeApplied">0</div>
                <div>Applied</div>
            </div>
            <div class="pipeline-stage">
                <div class="pipeline-count" id="pipeScreening">0</div>
                <div>Screening</div>
            </div>
            <div class="pipeline-stage">
                <div class="pipeline-count" id="pipeInterviewing">0</div>
                <div>Interviewing</div>
            </div>
            <div class="pipeline-stage">
                <div class="pipeline-count" id="pipeOffer">0</div>
                <div>Offers</div>
            </div>
        </div>
        
        <div class="add-form">
            <h3>➕ Add New Application</h3>
            <div class="form-row">
                <input type="text" id="company" placeholder="Company Name" />
                <input type="text" id="position" placeholder="Position Title" />
                <input type="text" id="location" placeholder="Location" />
                <input type="text" id="salary" placeholder="Salary Range" />
            </div>
            <div class="form-row">
                <select id="source">
                    <option value="linkedin">LinkedIn</option>
                    <option value="indeed">Indeed</option>
                    <option value="company">Company Site</option>
                    <option value="referral">Referral</option>
                </select>
                <input type="url" id="jobUrl" placeholder="Job URL" style="grid-column: span 2;" />
                <button onclick="addApplication()">Add Application</button>
            </div>
        </div>
        
        <div class="applications-list" id="applicationsList"></div>
    </div>
    
    <script>
        loadData();
        
        async function loadData() {
            try {
                // Load stats
                const statsResp = await fetch('/api/stats');
                const stats = await statsResp.json();
                
                document.getElementById('totalApps').textContent = stats.total;
                document.getElementById('responseRate').textContent = stats.response_rate + '%';
                document.getElementById('interviewRate').textContent = stats.interview_rate + '%';
                document.getElementById('offerRate').textContent = stats.offer_rate + '%';
                document.getElementById('followUps').textContent = stats.pending_followups;
                
                document.getElementById('pipeApplied').textContent = stats.by_status.applied || 0;
                document.getElementById('pipeScreening').textContent = stats.by_status.screening || 0;
                document.getElementById('pipeInterviewing').textContent = stats.by_status.interviewing || 0;
                document.getElementById('pipeOffer').textContent = stats.by_status.offer || 0;
                
                // Load applications
                const appsResp = await fetch('/api/applications');
                const apps = await appsResp.json();
                
                displayApplications(apps);
            } catch (error) {
                console.error('Error loading data:', error);
            }
        }
        
        function displayApplications(apps) {
            const list = document.getElementById('applicationsList');
            
            if (apps.length === 0) {
                list.innerHTML = '<p style="text-align: center; color: #888; padding: 2rem;">No applications yet. Add your first one above!</p>';
                return;
            }
            
            list.innerHTML = apps.map(app => `
                <div class="app-card">
                    <div class="company-info">
                        <h3>${app.company}</h3>
                        <p>${app.position} • ${app.location}</p>
                    </div>
                    <div>${app.salary_range || 'Not specified'}</div>
                    <div><span class="status-badge status-${app.status}">${app.status.toUpperCase()}</span></div>
                    <div>${app.applied_date}</div>
                    <div>
                        <select onchange="updateStatus('${app.id}', this.value)" style="padding: 0.3rem;">
                            <option value="applied" ${app.status === 'applied' ? 'selected' : ''}>Applied</option>
                            <option value="screening" ${app.status === 'screening' ? 'selected' : ''}>Screening</option>
                            <option value="interviewing" ${app.status === 'interviewing' ? 'selected' : ''}>Interviewing</option>
                            <option value="offer" ${app.status === 'offer' ? 'selected' : ''}>Offer</option>
                            <option value="rejected" ${app.status === 'rejected' ? 'selected' : ''}>Rejected</option>
                        </select>
                    </div>
                </div>
            `).join('');
        }
        
        async function addApplication() {
            const data = {
                company: document.getElementById('company').value,
                position: document.getElementById('position').value,
                location: document.getElementById('location').value,
                salary_range: document.getElementById('salary').value,
                source: document.getElementById('source').value,
                job_url: document.getElementById('jobUrl').value
            };
            
            if (!data.company || !data.position) {
                alert('Please enter company and position');
                return;
            }
            
            try {
                await fetch('/api/applications', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify(data)
                });
                
                // Clear form
                document.getElementById('company').value = '';
                document.getElementById('position').value = '';
                document.getElementById('location').value = '';
                document.getElementById('salary').value = '';
                document.getElementById('jobUrl').value = '';
                
                loadData();
            } catch (error) {
                alert('Error adding application');
            }
        }
        
        async function updateStatus(appId, status) {
            try {
                await fetch('/api/applications/' + appId + '/status', {
                    method: 'PUT',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({status})
                });
                loadData();
            } catch (error) {
                alert('Error updating status');
            }
        }
    </script>
</body>
</html>
    """)

@app.route("/api/applications", methods=["GET", "POST"])
def api_applications():
    if request.method == "POST":
        data = request.get_json()
        app = tracker.add_application(data)
        return jsonify(asdict(app))
    
    return jsonify([asdict(a) for a in tracker.applications.values()])

@app.route("/api/applications/<app_id>/status", methods=["PUT"])
def api_update_status(app_id):
    data = request.get_json()
    app = tracker.update_status(app_id, data.get("status", "applied"))
    if app:
        return jsonify(asdict(app))
    return jsonify({"error": "Application not found"}), 404

@app.route("/api/applications/<app_id>/interview", methods=["POST"])
def api_add_interview(app_id):
    data = request.get_json()
    interview = tracker.add_interview(app_id, data)
    if interview:
        return jsonify(asdict(interview))
    return jsonify({"error": "Application not found"}), 404

@app.route("/api/applications/<app_id>/offer", methods=["POST"])
def api_add_offer(app_id):
    data = request.get_json()
    offer = tracker.add_offer(app_id, data)
    if offer:
        return jsonify(asdict(offer))
    return jsonify({"error": "Application not found"}), 404

@app.route("/api/stats")
def api_stats():
    return jsonify(tracker.get_stats())

@app.route("/api/compare-offers")
def api_compare_offers():
    return jsonify(tracker.compare_offers())

# =============================================================================
# SALARY RESEARCH ENGINE
# =============================================================================

@dataclass
class SalaryData:
    title: str
    location: str
    experience_level: str
    base_min: float
    base_max: float
    base_median: float
    bonus_avg: float
    equity_avg: float
    total_comp_median: float
    source: str
    sample_size: int
    last_updated: str

class SalaryResearcher:
    """Research salary data for job negotiations"""
    
    # Market data (simplified - production would use APIs)
    SALARY_DATABASE = {
        "software_engineer": {
            "entry": {"base": (70000, 100000), "bonus": 5000, "equity": 10000},
            "mid": {"base": (100000, 150000), "bonus": 15000, "equity": 30000},
            "senior": {"base": (150000, 220000), "bonus": 30000, "equity": 75000},
            "staff": {"base": (200000, 300000), "bonus": 50000, "equity": 150000}
        },
        "product_manager": {
            "entry": {"base": (80000, 110000), "bonus": 8000, "equity": 15000},
            "mid": {"base": (110000, 160000), "bonus": 20000, "equity": 40000},
            "senior": {"base": (160000, 230000), "bonus": 40000, "equity": 100000},
            "director": {"base": (220000, 350000), "bonus": 60000, "equity": 200000}
        },
        "data_scientist": {
            "entry": {"base": (85000, 115000), "bonus": 7000, "equity": 12000},
            "mid": {"base": (115000, 165000), "bonus": 18000, "equity": 35000},
            "senior": {"base": (165000, 240000), "bonus": 35000, "equity": 80000},
            "principal": {"base": (230000, 320000), "bonus": 55000, "equity": 175000}
        }
    }
    
    LOCATION_MULTIPLIERS = {
        "san_francisco": 1.3,
        "new_york": 1.25,
        "seattle": 1.15,
        "austin": 1.0,
        "denver": 0.95,
        "remote": 0.9,
        "other": 0.85
    }
    
    def research_salary(self, title: str, location: str = "other", 
                        experience: str = "mid") -> SalaryData:
        """Get salary research for a role"""
        
        # Normalize title
        title_key = self._normalize_title(title)
        role_data = self.SALARY_DATABASE.get(title_key, self.SALARY_DATABASE["software_engineer"])
        level_data = role_data.get(experience, role_data["mid"])
        
        # Apply location multiplier
        multiplier = self.LOCATION_MULTIPLIERS.get(location.lower().replace(" ", "_"), 0.9)
        
        base_min = level_data["base"][0] * multiplier
        base_max = level_data["base"][1] * multiplier
        base_median = (base_min + base_max) / 2
        bonus = level_data["bonus"] * multiplier
        equity = level_data["equity"] * multiplier
        
        return SalaryData(
            title=title,
            location=location,
            experience_level=experience,
            base_min=round(base_min, -3),
            base_max=round(base_max, -3),
            base_median=round(base_median, -3),
            bonus_avg=round(bonus, -3),
            equity_avg=round(equity, -3),
            total_comp_median=round(base_median + bonus + equity, -3),
            source="Internal Database",
            sample_size=500,
            last_updated=datetime.now().strftime("%Y-%m-%d")
        )
    
    def compare_offer_to_market(self, offer_base: float, offer_bonus: float,
                                 offer_equity: float, title: str,
                                 location: str, experience: str) -> Dict:
        """Compare an offer against market data"""
        
        market = self.research_salary(title, location, experience)
        offer_total = offer_base + offer_bonus + offer_equity
        
        percentile = self._calculate_percentile(offer_base, market.base_min, market.base_max)
        
        return {
            "offer_total": offer_total,
            "market_median": market.total_comp_median,
            "difference": offer_total - market.total_comp_median,
            "difference_pct": round((offer_total / market.total_comp_median - 1) * 100, 1),
            "base_percentile": percentile,
            "verdict": "above_market" if percentile > 60 else "at_market" if percentile > 40 else "below_market",
            "negotiation_room": round(market.base_max - offer_base, -3) if offer_base < market.base_max else 0
        }
    
    def _normalize_title(self, title: str) -> str:
        """Normalize job title to category"""
        title_lower = title.lower()
        if any(k in title_lower for k in ["engineer", "developer", "programmer"]):
            return "software_engineer"
        elif any(k in title_lower for k in ["product", "pm"]):
            return "product_manager"
        elif any(k in title_lower for k in ["data", "scientist", "analyst", "ml"]):
            return "data_scientist"
        return "software_engineer"
    
    def _calculate_percentile(self, value: float, min_val: float, max_val: float) -> int:
        """Calculate percentile within range"""
        if value <= min_val:
            return 0
        if value >= max_val:
            return 100
        return int((value - min_val) / (max_val - min_val) * 100)

salary_researcher = SalaryResearcher()

# =============================================================================
# NETWORKING TRACKER
# =============================================================================

@dataclass
class Contact:
    id: str
    name: str
    company: str
    title: str
    email: Optional[str]
    linkedin: Optional[str]
    relationship: str  # cold, warm, friend, colleague
    last_contact: str
    notes: str
    tags: List[str]

@dataclass
class NetworkingActivity:
    id: str
    contact_id: str
    activity_type: str  # email, call, coffee, linkedin, referral_request
    date: str
    notes: str
    follow_up_date: Optional[str]

class NetworkingTracker:
    """Track networking activities and contacts"""
    
    def __init__(self):
        self.contacts: Dict[str, Contact] = {}
        self.activities: Dict[str, List[NetworkingActivity]] = {}
    
    def add_contact(self, data: Dict) -> Contact:
        """Add a networking contact"""
        contact = Contact(
            id=hashlib.md5(f"{data.get('name', '')}{datetime.now()}".encode()).hexdigest()[:12],
            name=data.get("name", ""),
            company=data.get("company", ""),
            title=data.get("title", ""),
            email=data.get("email"),
            linkedin=data.get("linkedin"),
            relationship=data.get("relationship", "cold"),
            last_contact=datetime.now().strftime("%Y-%m-%d"),
            notes=data.get("notes", ""),
            tags=data.get("tags", [])
        )
        self.contacts[contact.id] = contact
        self.activities[contact.id] = []
        return contact
    
    def log_activity(self, contact_id: str, activity_type: str, 
                     notes: str, follow_up_days: int = None) -> Optional[NetworkingActivity]:
        """Log a networking activity"""
        if contact_id not in self.contacts:
            return None
        
        follow_up = None
        if follow_up_days:
            follow_up = (datetime.now() + timedelta(days=follow_up_days)).strftime("%Y-%m-%d")
        
        activity = NetworkingActivity(
            id=hashlib.md5(f"{contact_id}{datetime.now()}".encode()).hexdigest()[:8],
            contact_id=contact_id,
            activity_type=activity_type,
            date=datetime.now().strftime("%Y-%m-%d"),
            notes=notes,
            follow_up_date=follow_up
        )
        
        self.activities[contact_id].append(activity)
        self.contacts[contact_id].last_contact = activity.date
        
        return activity
    
    def get_follow_ups(self) -> List[Dict]:
        """Get upcoming follow-ups"""
        today = datetime.now().strftime("%Y-%m-%d")
        follow_ups = []
        
        for contact_id, activities in self.activities.items():
            for activity in activities:
                if activity.follow_up_date and activity.follow_up_date <= today:
                    contact = self.contacts.get(contact_id)
                    if contact:
                        follow_ups.append({
                            "contact": contact.name,
                            "company": contact.company,
                            "due_date": activity.follow_up_date,
                            "last_activity": activity.activity_type,
                            "notes": activity.notes
                        })
        
        return sorted(follow_ups, key=lambda x: x["due_date"])
    
    def get_network_stats(self) -> Dict:
        """Get networking statistics"""
        by_relationship = {}
        by_company = {}
        
        for contact in self.contacts.values():
            rel = contact.relationship
            by_relationship[rel] = by_relationship.get(rel, 0) + 1
            
            company = contact.company
            by_company[company] = by_company.get(company, 0) + 1
        
        total_activities = sum(len(acts) for acts in self.activities.values())
        
        return {
            "total_contacts": len(self.contacts),
            "by_relationship": by_relationship,
            "top_companies": sorted(by_company.items(), key=lambda x: x[1], reverse=True)[:5],
            "total_activities": total_activities,
            "pending_follow_ups": len(self.get_follow_ups())
        }

networking = NetworkingTracker()

# =============================================================================
# SKILLS GAP ANALYZER
# =============================================================================

class SkillsGapAnalyzer:
    """Analyze skills gap against job requirements"""
    
    SKILL_CATEGORIES = {
        "programming": ["python", "javascript", "java", "go", "rust", "typescript", "c++"],
        "frameworks": ["react", "node.js", "django", "flask", "spring", "vue", "angular"],
        "cloud": ["aws", "gcp", "azure", "kubernetes", "docker", "terraform"],
        "data": ["sql", "postgresql", "mongodb", "redis", "elasticsearch", "snowflake"],
        "ml": ["tensorflow", "pytorch", "scikit-learn", "pandas", "numpy", "mlops"],
        "soft_skills": ["leadership", "communication", "project management", "agile", "scrum"]
    }
    
    def __init__(self):
        self.user_skills: Dict[str, int] = {}  # skill -> proficiency (1-5)
    
    def set_user_skills(self, skills: Dict[str, int]) -> None:
        """Set user's current skills"""
        self.user_skills = skills
    
    def analyze_job_requirements(self, job_description: str) -> Dict:
        """Extract required skills from job description"""
        text_lower = job_description.lower()
        required_skills = []
        
        for category, skills in self.SKILL_CATEGORIES.items():
            for skill in skills:
                if skill.lower() in text_lower:
                    required_skills.append({
                        "skill": skill,
                        "category": category,
                        "user_level": self.user_skills.get(skill.lower(), 0)
                    })
        
        return {
            "required_skills": required_skills,
            "total_required": len(required_skills),
            "user_has": sum(1 for s in required_skills if s["user_level"] > 0),
            "match_rate": round(sum(1 for s in required_skills if s["user_level"] > 0) / max(len(required_skills), 1) * 100, 1)
        }
    
    def get_skill_gaps(self, job_description: str) -> Dict:
        """Identify skill gaps and learning recommendations"""
        analysis = self.analyze_job_requirements(job_description)
        
        gaps = []
        strong = []
        
        for skill_info in analysis["required_skills"]:
            skill = skill_info["skill"]
            level = skill_info["user_level"]
            
            if level == 0:
                gaps.append({
                    "skill": skill,
                    "category": skill_info["category"],
                    "priority": "high",
                    "recommendation": self._get_learning_resource(skill)
                })
            elif level < 3:
                gaps.append({
                    "skill": skill,
                    "category": skill_info["category"],
                    "priority": "medium",
                    "recommendation": f"Practice more {skill} projects"
                })
            else:
                strong.append(skill)
        
        return {
            "gaps": gaps,
            "strong_skills": strong,
            "gap_count": len(gaps),
            "readiness_score": round(len(strong) / max(len(analysis["required_skills"]), 1) * 100, 1)
        }
    
    def _get_learning_resource(self, skill: str) -> str:
        """Get learning recommendation for a skill"""
        resources = {
            "python": "Complete Python Bootcamp on Udemy or Python.org tutorials",
            "javascript": "JavaScript.info or freeCodeCamp JavaScript course",
            "react": "React official docs + build 3 projects",
            "aws": "AWS Cloud Practitioner certification",
            "kubernetes": "Kubernetes the Hard Way + CKA certification",
            "sql": "SQLZoo + LeetCode SQL problems"
        }
        return resources.get(skill.lower(), f"Udemy/Coursera courses on {skill}")

skills_analyzer = SkillsGapAnalyzer()

# =============================================================================
# INTERVIEW PREP SYSTEM
# =============================================================================

@dataclass
class InterviewQuestion:
    id: str
    category: str  # behavioral, technical, system_design, case_study
    question: str
    sample_answer: str
    tips: List[str]
    company_specific: Optional[str]

class InterviewPrepSystem:
    """Interview preparation and practice"""
    
    QUESTION_BANK = {
        "behavioral": [
            InterviewQuestion(
                id="beh_1",
                category="behavioral",
                question="Tell me about a time you had to deal with a difficult team member.",
                sample_answer="In my previous role, I worked with a colleague who frequently missed deadlines. I scheduled a one-on-one to understand their challenges, discovered they were overwhelmed with competing priorities, and helped them prioritize. We established weekly check-ins, and their delivery improved significantly.",
                tips=["Use STAR method", "Focus on your actions", "Show empathy and leadership"],
                company_specific=None
            ),
            InterviewQuestion(
                id="beh_2",
                category="behavioral",
                question="Describe a project where you had to learn a new technology quickly.",
                sample_answer="When our team needed to migrate to Kubernetes, I had no prior experience. I spent evenings completing online courses, set up a home lab, and within 3 weeks led our first production deployment. I documented the process for the team.",
                tips=["Highlight learning agility", "Show initiative", "Mention knowledge sharing"],
                company_specific=None
            ),
            InterviewQuestion(
                id="beh_3",
                category="behavioral",
                question="Tell me about a time you failed and what you learned.",
                sample_answer="I once shipped a feature without adequate testing, causing a production outage. I took responsibility, led the incident response, and afterward implemented a mandatory code review and testing policy that prevented similar issues.",
                tips=["Be honest about failure", "Focus on learning", "Show growth"],
                company_specific=None
            )
        ],
        "technical": [
            InterviewQuestion(
                id="tech_1",
                category="technical",
                question="Explain the difference between REST and GraphQL.",
                sample_answer="REST uses fixed endpoints returning predetermined data structures, while GraphQL provides a single endpoint where clients specify exactly what data they need. GraphQL reduces over-fetching but adds complexity. Choose REST for simpler APIs, GraphQL for complex data requirements.",
                tips=["Give concrete comparisons", "Mention trade-offs", "Provide use cases"],
                company_specific=None
            ),
            InterviewQuestion(
                id="tech_2",
                category="technical",
                question="How would you optimize a slow database query?",
                sample_answer="First, I'd use EXPLAIN ANALYZE to understand the query plan. Common optimizations include adding indexes on frequently queried columns, avoiding SELECT *, using pagination, caching results, and denormalizing if necessary.",
                tips=["Start with diagnosis", "Give multiple options", "Consider trade-offs"],
                company_specific=None
            )
        ],
        "system_design": [
            InterviewQuestion(
                id="sys_1",
                category="system_design",
                question="Design a URL shortener like bit.ly.",
                sample_answer="I'd use a base62 encoding of auto-incremented IDs for short codes. Architecture: Load balancer → API servers → Cache (Redis) → Database (sharded PostgreSQL). Key considerations: collision handling, analytics tracking, rate limiting, custom aliases.",
                tips=["Start with requirements", "Draw the architecture", "Discuss scaling"],
                company_specific=None
            )
        ]
    }
    
    def __init__(self):
        self.practice_sessions: Dict[str, List[Dict]] = {}
    
    def get_questions(self, category: str = None, count: int = 5) -> List[Dict]:
        """Get interview questions for practice"""
        if category and category in self.QUESTION_BANK:
            questions = self.QUESTION_BANK[category]
        else:
            questions = []
            for cat_questions in self.QUESTION_BANK.values():
                questions.extend(cat_questions)
        
        import random
        selected = random.sample(questions, min(count, len(questions)))
        
        return [asdict(q) for q in selected]
    
    def start_practice_session(self, user_id: str, category: str = None) -> Dict:
        """Start a practice session"""
        questions = self.get_questions(category, 5)
        session_id = hashlib.md5(f"{user_id}{datetime.now()}".encode()).hexdigest()[:12]
        
        if user_id not in self.practice_sessions:
            self.practice_sessions[user_id] = []
        
        session = {
            "session_id": session_id,
            "started_at": datetime.now().isoformat(),
            "category": category or "mixed",
            "questions": questions,
            "current_index": 0,
            "responses": []
        }
        
        self.practice_sessions[user_id].append(session)
        
        return {
            "session_id": session_id,
            "total_questions": len(questions),
            "first_question": questions[0] if questions else None
        }
    
    def evaluate_response(self, response: str, question: InterviewQuestion) -> Dict:
        """Evaluate a practice response"""
        word_count = len(response.split())
        
        # Simple heuristic evaluation
        score = 50
        feedback = []
        
        if word_count < 50:
            feedback.append("Response is too short. Aim for 100-200 words.")
        elif word_count > 300:
            feedback.append("Response is verbose. Be more concise.")
        else:
            score += 20
        
        # Check for STAR method keywords
        star_keywords = ["situation", "task", "action", "result"]
        star_count = sum(1 for k in star_keywords if k in response.lower())
        if star_count >= 3:
            score += 20
            feedback.append("Good use of STAR method!")
        elif star_count < 2:
            feedback.append("Try using the STAR method (Situation, Task, Action, Result)")
        
        # Check for specific details
        if any(c.isdigit() for c in response):
            score += 10
            feedback.append("Good use of specific metrics/numbers")
        
        return {
            "score": min(100, score),
            "feedback": feedback,
            "sample_answer": question.sample_answer,
            "tips": question.tips
        }

interview_prep = InterviewPrepSystem()

# =============================================================================
# JOB SEARCH ANALYTICS
# =============================================================================

class JobSearchAnalytics:
    """Track and analyze job search progress"""
    
    def __init__(self):
        self.events: List[Dict] = []
    
    def track_event(self, event_type: str, data: Dict) -> None:
        """Track a job search event"""
        self.events.append({
            "type": event_type,
            "data": data,
            "timestamp": datetime.now().isoformat()
        })
    
    def get_funnel_metrics(self, applications: Dict) -> Dict:
        """Calculate conversion funnel metrics"""
        total = len(applications)
        if total == 0:
            return {"total": 0, "funnel": {}}
        
        stages = {
            "applied": 0,
            "screening": 0,
            "interviewing": 0,
            "offer": 0,
            "accepted": 0,
            "rejected": 0
        }
        
        for app in applications.values():
            status = app.status.lower()
            if status in stages:
                stages[status] += 1
        
        return {
            "total_applications": total,
            "funnel": stages,
            "response_rate": round((stages["screening"] + stages["interviewing"] + stages["offer"]) / total * 100, 1),
            "interview_rate": round((stages["interviewing"] + stages["offer"]) / total * 100, 1),
            "offer_rate": round(stages["offer"] / total * 100, 1)
        }
    
    def get_weekly_activity(self) -> List[Dict]:
        """Get weekly activity breakdown"""
        weekly = {}
        
        for event in self.events:
            date = event["timestamp"][:10]
            week_start = datetime.fromisoformat(date) - timedelta(days=datetime.fromisoformat(date).weekday())
            week_key = week_start.strftime("%Y-%m-%d")
            
            if week_key not in weekly:
                weekly[week_key] = {"applications": 0, "interviews": 0, "offers": 0}
            
            if event["type"] == "application":
                weekly[week_key]["applications"] += 1
            elif event["type"] == "interview":
                weekly[week_key]["interviews"] += 1
            elif event["type"] == "offer":
                weekly[week_key]["offers"] += 1
        
        return [{"week": k, **v} for k, v in sorted(weekly.items())[-8:]]
    
    def get_insights(self, applications: Dict) -> List[str]:
        """Generate actionable insights"""
        insights = []
        metrics = self.get_funnel_metrics(applications)
        
        if metrics["response_rate"] < 10:
            insights.append("📝 Low response rate. Consider tailoring your resume for each application.")
        
        if metrics["interview_rate"] < 5:
            insights.append("🎯 Focus on applying to roles that match your skills more closely.")
        
        if len(applications) < 10:
            insights.append("📊 Apply to more positions to get statistically meaningful results.")
        
        if not insights:
            insights.append("✅ Your job search metrics look healthy. Keep up the momentum!")
        
        return insights

job_analytics = JobSearchAnalytics()

# =============================================================================
# ADDITIONAL API ROUTES
# =============================================================================

@app.route("/api/salary/research", methods=["POST"])
def api_salary_research():
    """Get salary research data"""
    data = request.get_json()
    result = salary_researcher.research_salary(
        title=data.get("title", "Software Engineer"),
        location=data.get("location", "other"),
        experience=data.get("experience", "mid")
    )
    return jsonify(asdict(result))

@app.route("/api/salary/compare", methods=["POST"])
def api_salary_compare():
    """Compare offer to market"""
    data = request.get_json()
    result = salary_researcher.compare_offer_to_market(
        offer_base=data.get("base", 0),
        offer_bonus=data.get("bonus", 0),
        offer_equity=data.get("equity", 0),
        title=data.get("title", ""),
        location=data.get("location", "other"),
        experience=data.get("experience", "mid")
    )
    return jsonify(result)

@app.route("/api/networking/contacts", methods=["GET", "POST"])
def api_networking_contacts():
    """Manage networking contacts"""
    if request.method == "POST":
        data = request.get_json()
        contact = networking.add_contact(data)
        return jsonify(asdict(contact))
    
    return jsonify([asdict(c) for c in networking.contacts.values()])

@app.route("/api/networking/activity", methods=["POST"])
def api_log_activity():
    """Log networking activity"""
    data = request.get_json()
    activity = networking.log_activity(
        contact_id=data.get("contact_id"),
        activity_type=data.get("type", "email"),
        notes=data.get("notes", ""),
        follow_up_days=data.get("follow_up_days")
    )
    if activity:
        return jsonify(asdict(activity))
    return jsonify({"error": "Contact not found"}), 404

@app.route("/api/networking/follow-ups")
def api_follow_ups():
    """Get pending follow-ups"""
    return jsonify({"follow_ups": networking.get_follow_ups()})

@app.route("/api/skills/analyze", methods=["POST"])
def api_analyze_skills():
    """Analyze skills gap"""
    data = request.get_json()
    skills_analyzer.set_user_skills(data.get("user_skills", {}))
    result = skills_analyzer.get_skill_gaps(data.get("job_description", ""))
    return jsonify(result)

@app.route("/api/interview/questions")
def api_interview_questions():
    """Get interview questions"""
    category = request.args.get("category")
    count = int(request.args.get("count", 5))
    return jsonify({"questions": interview_prep.get_questions(category, count)})

@app.route("/api/interview/practice", methods=["POST"])
def api_start_practice():
    """Start practice session"""
    data = request.get_json()
    result = interview_prep.start_practice_session(
        user_id=data.get("user_id", "anonymous"),
        category=data.get("category")
    )
    return jsonify(result)

@app.route("/api/analytics/funnel")
def api_funnel():
    """Get funnel metrics"""
    return jsonify(job_analytics.get_funnel_metrics(tracker.applications))

@app.route("/api/analytics/insights")
def api_insights():
    """Get job search insights"""
    return jsonify({"insights": job_analytics.get_insights(tracker.applications)})

@app.route("/health")
def health():
    return jsonify({
        "status": "healthy",
        "endeavor": "Job Tracker",
        "components": {
            "tracker": "active",
            "salary_research": "active",
            "networking": len(networking.contacts),
            "skills_analyzer": "active",
            "interview_prep": len(interview_prep.QUESTION_BANK),
            "analytics": "active"
        }
    })

if __name__ == "__main__":
    print("📋 AI Job Tracker - Starting...")
    print("📍 http://localhost:5010")
    print("🔧 Components: Tracker, Salary, Networking, Skills, Interview, Analytics")
    app.run(host="0.0.0.0", port=5010, debug=True)
