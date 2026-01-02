#!/bin/bash

# OrbitV3 Demo Recording Script
# ==============================
# Automates simulator recording for demo video

set -e

# Configuration
PROJECT_DIR="/Users/jlow/Desktop/OrbitV3Full"
OUTPUT_DIR="/Users/jlow/Desktop/OrbitV3Full/docs/demo_recordings"
SIMULATOR_NAME="iPhone 17 Pro"
RECORDING_DURATION=60  # seconds

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[DEMO]${NC} $1"
}

# Create output directory
mkdir -p "${OUTPUT_DIR}"

# Find the built app
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/OrbitV3Full-*/Build/Products/Debug-iphonesimulator -name "OrbitV3Full.app" 2>/dev/null | head -1)

if [ -z "$APP_PATH" ]; then
    log "App not found. Building first..."
    cd "${PROJECT_DIR}"
    ./scripts/deploy_ios.sh simulator
    APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/OrbitV3Full-*/Build/Products/Debug-iphonesimulator -name "OrbitV3Full.app" 2>/dev/null | head -1)
fi

log "Using app: ${APP_PATH}"

# Get simulator UDID
SIMULATOR_UDID=$(xcrun simctl list devices available | grep "${SIMULATOR_NAME}" | grep -oE "[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}" | head -1)

if [ -z "$SIMULATOR_UDID" ]; then
    echo "Error: Simulator '${SIMULATOR_NAME}' not found"
    exit 1
fi

log "Found simulator: ${SIMULATOR_NAME} (${SIMULATOR_UDID})"

# Boot simulator
log "Booting simulator..."
xcrun simctl boot "${SIMULATOR_UDID}" 2>/dev/null || true

# Wait for boot
sleep 3

# Open Simulator app
open -a Simulator

# Wait for UI
sleep 2

# Install app
log "Installing app..."
xcrun simctl install "${SIMULATOR_UDID}" "${APP_PATH}"

# Launch app
log "Launching Orbit V3..."
xcrun simctl launch "${SIMULATOR_UDID}" com.antigravity.orbitv3full

# Wait for app to load
sleep 3

# Start recording
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
VIDEO_PATH="${OUTPUT_DIR}/orbit_demo_${TIMESTAMP}.mp4"

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  🎬 DEMO RECORDING STARTED${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo ""
echo -e "  Recording to: ${VIDEO_PATH}"
echo ""
echo -e "  ${YELLOW}Interact with the app now!${NC}"
echo ""
echo -e "  Suggested demo flow:"
echo "  1. Show the Solar System rotating"
echo "  2. Tap on different planets"
echo "  3. Open the command interface"
echo "  4. Show device controls"
echo ""
echo -e "  ${YELLOW}Press Ctrl+C to stop recording${NC}"
echo ""

# Record
xcrun simctl io "${SIMULATOR_UDID}" recordVideo "${VIDEO_PATH}"

echo ""
log "Recording saved to: ${VIDEO_PATH}"
echo ""

# Generate thumbnail
log "Generating thumbnail..."
ffmpeg -i "${VIDEO_PATH}" -ss 00:00:05 -vframes 1 "${OUTPUT_DIR}/orbit_thumbnail_${TIMESTAMP}.png" 2>/dev/null || true

log "Done! Files saved to ${OUTPUT_DIR}"
echo ""
echo "Next steps:"
echo "  1. Review the recording"
echo "  2. Edit in iMovie/CapCut if needed"
echo "  3. Upload to YouTube"
echo "  4. Update hackathon submissions"
