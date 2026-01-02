#!/bin/bash
# Generate SVG icons for all 15 endeavors

# 01 - Fitness (Green)
cat > 01_fitness.svg << 'END'
<svg viewBox="0 0 120 120" xmlns="http://www.w3.org/2000/svg"><defs><linearGradient id="g" x1="0%" y1="0%" x2="100%" y2="100%"><stop offset="0%" style="stop-color:#10B981"/><stop offset="100%" style="stop-color:#059669"/></linearGradient></defs><rect width="120" height="120" rx="24" fill="url(#g)"/><text x="60" y="65" font-family="Arial" font-size="50" fill="white" text-anchor="middle">🏋️</text><text x="60" y="100" font-family="Arial,sans-serif" font-size="11" font-weight="bold" fill="white" text-anchor="middle">FITNESS</text></svg>
END

# 02 - Podcast (Purple)
cat > 02_podcast.svg << 'END'
<svg viewBox="0 0 120 120" xmlns="http://www.w3.org/2000/svg"><defs><linearGradient id="g" x1="0%" y1="0%" x2="100%" y2="100%"><stop offset="0%" style="stop-color:#8B5CF6"/><stop offset="100%" style="stop-color:#6366F1"/></linearGradient></defs><rect width="120" height="120" rx="24" fill="url(#g)"/><text x="60" y="65" font-family="Arial" font-size="50" fill="white" text-anchor="middle">🎙️</text><text x="60" y="100" font-family="Arial,sans-serif" font-size="11" font-weight="bold" fill="white" text-anchor="middle">PODCAST</text></svg>
END

# 03 - Phone (Teal)
cat > 03_phone.svg << 'END'
<svg viewBox="0 0 120 120" xmlns="http://www.w3.org/2000/svg"><defs><linearGradient id="g" x1="0%" y1="0%" x2="100%" y2="100%"><stop offset="0%" style="stop-color:#14B8A6"/><stop offset="100%" style="stop-color:#0891B2"/></linearGradient></defs><rect width="120" height="120" rx="24" fill="url(#g)"/><text x="60" y="65" font-family="Arial" font-size="50" fill="white" text-anchor="middle">📞</text><text x="60" y="100" font-family="Arial,sans-serif" font-size="11" font-weight="bold" fill="white" text-anchor="middle">VOICE AI</text></svg>
END

# 04 - Landing Page (Orange)
cat > 04_landing.svg << 'END'
<svg viewBox="0 0 120 120" xmlns="http://www.w3.org/2000/svg"><defs><linearGradient id="g" x1="0%" y1="0%" x2="100%" y2="100%"><stop offset="0%" style="stop-color:#F59E0B"/><stop offset="100%" style="stop-color:#D97706"/></linearGradient></defs><rect width="120" height="120" rx="24" fill="url(#g)"/><text x="60" y="65" font-family="Arial" font-size="50" fill="white" text-anchor="middle">🌐</text><text x="60" y="100" font-family="Arial,sans-serif" font-size="11" font-weight="bold" fill="white" text-anchor="middle">PAGES</text></svg>
END

# 05 - Drone (Red/Navy)
cat > 05_drone.svg << 'END'
<svg viewBox="0 0 120 120" xmlns="http://www.w3.org/2000/svg"><defs><linearGradient id="g" x1="0%" y1="0%" x2="100%" y2="100%"><stop offset="0%" style="stop-color:#1E3A8A"/><stop offset="100%" style="stop-color:#DC2626"/></linearGradient></defs><rect width="120" height="120" rx="24" fill="url(#g)"/><text x="60" y="65" font-family="Arial" font-size="50" fill="white" text-anchor="middle">🚁</text><text x="60" y="100" font-family="Arial,sans-serif" font-size="11" font-weight="bold" fill="white" text-anchor="middle">DRONE</text></svg>
END

# 06 - Finance (Cyan)
cat > 06_finance.svg << 'END'
<svg viewBox="0 0 120 120" xmlns="http://www.w3.org/2000/svg"><defs><linearGradient id="g" x1="0%" y1="0%" x2="100%" y2="100%"><stop offset="0%" style="stop-color:#0EA5E9"/><stop offset="100%" style="stop-color:#0284C7"/></linearGradient></defs><rect width="120" height="120" rx="24" fill="url(#g)"/><text x="60" y="65" font-family="Arial" font-size="50" fill="white" text-anchor="middle">💰</text><text x="60" y="100" font-family="Arial,sans-serif" font-size="11" font-weight="bold" fill="white" text-anchor="middle">FINANCE</text></svg>
END

# 07 - Contract (Slate)
cat > 07_contract.svg << 'END'
<svg viewBox="0 0 120 120" xmlns="http://www.w3.org/2000/svg"><defs><linearGradient id="g" x1="0%" y1="0%" x2="100%" y2="100%"><stop offset="0%" style="stop-color:#475569"/><stop offset="100%" style="stop-color:#1E293B"/></linearGradient></defs><rect width="120" height="120" rx="24" fill="url(#g)"/><text x="60" y="65" font-family="Arial" font-size="50" fill="white" text-anchor="middle">📜</text><text x="60" y="100" font-family="Arial,sans-serif" font-size="11" font-weight="bold" fill="white" text-anchor="middle">LEGAL</text></svg>
END

# 08 - Meal (Lime)
cat > 08_meal.svg << 'END'
<svg viewBox="0 0 120 120" xmlns="http://www.w3.org/2000/svg"><defs><linearGradient id="g" x1="0%" y1="0%" x2="100%" y2="100%"><stop offset="0%" style="stop-color:#84CC16"/><stop offset="100%" style="stop-color:#65A30D"/></linearGradient></defs><rect width="120" height="120" rx="24" fill="url(#g)"/><text x="60" y="65" font-family="Arial" font-size="50" fill="white" text-anchor="middle">🥗</text><text x="60" y="100" font-family="Arial,sans-serif" font-size="11" font-weight="bold" fill="white" text-anchor="middle">NUTRITION</text></svg>
END

# 09 - Writing (Pink)
cat > 09_writing.svg << 'END'
<svg viewBox="0 0 120 120" xmlns="http://www.w3.org/2000/svg"><defs><linearGradient id="g" x1="0%" y1="0%" x2="100%" y2="100%"><stop offset="0%" style="stop-color:#EC4899"/><stop offset="100%" style="stop-color:#DB2777"/></linearGradient></defs><rect width="120" height="120" rx="24" fill="url(#g)"/><text x="60" y="65" font-family="Arial" font-size="50" fill="white" text-anchor="middle">✍️</text><text x="60" y="100" font-family="Arial,sans-serif" font-size="11" font-weight="bold" fill="white" text-anchor="middle">WRITING</text></svg>
END

# 10 - Job (Blue)
cat > 10_job.svg << 'END'
<svg viewBox="0 0 120 120" xmlns="http://www.w3.org/2000/svg"><defs><linearGradient id="g" x1="0%" y1="0%" x2="100%" y2="100%"><stop offset="0%" style="stop-color:#3B82F6"/><stop offset="100%" style="stop-color:#2563EB"/></linearGradient></defs><rect width="120" height="120" rx="24" fill="url(#g)"/><text x="60" y="65" font-family="Arial" font-size="50" fill="white" text-anchor="middle">📋</text><text x="60" y="100" font-family="Arial,sans-serif" font-size="11" font-weight="bold" fill="white" text-anchor="middle">JOBS</text></svg>
END

# 11 - Resume (Indigo)
cat > 11_resume.svg << 'END'
<svg viewBox="0 0 120 120" xmlns="http://www.w3.org/2000/svg"><defs><linearGradient id="g" x1="0%" y1="0%" x2="100%" y2="100%"><stop offset="0%" style="stop-color:#6366F1"/><stop offset="100%" style="stop-color:#4F46E5"/></linearGradient></defs><rect width="120" height="120" rx="24" fill="url(#g)"/><text x="60" y="65" font-family="Arial" font-size="50" fill="white" text-anchor="middle">📄</text><text x="60" y="100" font-family="Arial,sans-serif" font-size="11" font-weight="bold" fill="white" text-anchor="middle">RESUME</text></svg>
END

# 12 - Clip (Red)
cat > 12_clip.svg << 'END'
<svg viewBox="0 0 120 120" xmlns="http://www.w3.org/2000/svg"><defs><linearGradient id="g" x1="0%" y1="0%" x2="100%" y2="100%"><stop offset="0%" style="stop-color:#EF4444"/><stop offset="100%" style="stop-color:#DC2626"/></linearGradient></defs><rect width="120" height="120" rx="24" fill="url(#g)"/><text x="60" y="65" font-family="Arial" font-size="50" fill="white" text-anchor="middle">🎬</text><text x="60" y="100" font-family="Arial,sans-serif" font-size="11" font-weight="bold" fill="white" text-anchor="middle">CLIPS</text></svg>
END

# 13 - MCP (Violet)
cat > 13_mcp.svg << 'END'
<svg viewBox="0 0 120 120" xmlns="http://www.w3.org/2000/svg"><defs><linearGradient id="g" x1="0%" y1="0%" x2="100%" y2="100%"><stop offset="0%" style="stop-color:#8B5CF6"/><stop offset="100%" style="stop-color:#7C3AED"/></linearGradient></defs><rect width="120" height="120" rx="24" fill="url(#g)"/><text x="60" y="65" font-family="Arial" font-size="50" fill="white" text-anchor="middle">🔌</text><text x="60" y="100" font-family="Arial,sans-serif" font-size="11" font-weight="bold" fill="white" text-anchor="middle">MCP</text></svg>
END

# 14 - Email (Amber)
cat > 14_email.svg << 'END'
<svg viewBox="0 0 120 120" xmlns="http://www.w3.org/2000/svg"><defs><linearGradient id="g" x1="0%" y1="0%" x2="100%" y2="100%"><stop offset="0%" style="stop-color:#F59E0B"/><stop offset="100%" style="stop-color:#D97706"/></linearGradient></defs><rect width="120" height="120" rx="24" fill="url(#g)"/><text x="60" y="65" font-family="Arial" font-size="50" fill="white" text-anchor="middle">📧</text><text x="60" y="100" font-family="Arial,sans-serif" font-size="11" font-weight="bold" fill="white" text-anchor="middle">EMAIL</text></svg>
END

# 15 - Support (Emerald)
cat > 15_support.svg << 'END'
<svg viewBox="0 0 120 120" xmlns="http://www.w3.org/2000/svg"><defs><linearGradient id="g" x1="0%" y1="0%" x2="100%" y2="100%"><stop offset="0%" style="stop-color:#10B981"/><stop offset="100%" style="stop-color:#059669"/></linearGradient></defs><rect width="120" height="120" rx="24" fill="url(#g)"/><text x="60" y="65" font-family="Arial" font-size="50" fill="white" text-anchor="middle">🎧</text><text x="60" y="100" font-family="Arial,sans-serif" font-size="11" font-weight="bold" fill="white" text-anchor="middle">SUPPORT</text></svg>
END

echo "✅ All 15 SVG icons created"
