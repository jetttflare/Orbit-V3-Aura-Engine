#!/bin/bash

# OrbitV3Full iOS Deployment Script
# ==================================
# Automates build and deployment to TestFlight/App Store

set -e

# Configuration
PROJECT_DIR="/Users/jlow/Desktop/OrbitV3Full"
PROJECT_NAME="OrbitV3Full"
SCHEME="OrbitV3Full"
WORKSPACE=""  # Set if using workspace
BUNDLE_ID="com.antigravity.orbitv3full"
TEAM_ID="5DTUQN5C5R"

# Build directories
BUILD_DIR="${PROJECT_DIR}/build"
ARCHIVE_DIR="${BUILD_DIR}/Archives"
EXPORT_DIR="${BUILD_DIR}/Export"
LOG_DIR="${BUILD_DIR}/Logs"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Create directories
setup_directories() {
    log "Setting up build directories..."
    mkdir -p "${ARCHIVE_DIR}"
    mkdir -p "${EXPORT_DIR}"
    mkdir -p "${LOG_DIR}"
}

# Clean build
clean_build() {
    log "Cleaning previous builds..."
    xcodebuild clean \
        -project "${PROJECT_DIR}/${PROJECT_NAME}.xcodeproj" \
        -scheme "${SCHEME}" \
        -configuration Release \
        2>&1 | tee "${LOG_DIR}/clean.log"
}

# Build for iOS Device (Release)
build_release() {
    log "Building ${PROJECT_NAME} for iOS Release..."
    
    xcodebuild build \
        -project "${PROJECT_DIR}/${PROJECT_NAME}.xcodeproj" \
        -scheme "${SCHEME}" \
        -configuration Release \
        -destination 'generic/platform=iOS' \
        CODE_SIGN_STYLE=Automatic \
        DEVELOPMENT_TEAM="${TEAM_ID}" \
        2>&1 | tee "${LOG_DIR}/build.log"
    
    if [ $? -eq 0 ]; then
        log "✅ Build successful!"
    else
        error "Build failed. Check ${LOG_DIR}/build.log for details."
    fi
}

# Build for Simulator (Debug)
build_simulator() {
    log "Building ${PROJECT_NAME} for iOS Simulator..."
    
    xcodebuild build \
        -project "${PROJECT_DIR}/${PROJECT_NAME}.xcodeproj" \
        -scheme "${SCHEME}" \
        -configuration Debug \
        -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
        2>&1 | tee "${LOG_DIR}/build_simulator.log"
    
    if [ $? -eq 0 ]; then
        log "✅ Simulator build successful!"
    else
        error "Simulator build failed."
    fi
}

# Create Archive for App Store
archive() {
    log "Creating archive for App Store submission..."
    
    ARCHIVE_PATH="${ARCHIVE_DIR}/${PROJECT_NAME}_$(date '+%Y%m%d_%H%M%S').xcarchive"
    
    xcodebuild archive \
        -project "${PROJECT_DIR}/${PROJECT_NAME}.xcodeproj" \
        -scheme "${SCHEME}" \
        -configuration Release \
        -destination 'generic/platform=iOS' \
        -archivePath "${ARCHIVE_PATH}" \
        CODE_SIGN_STYLE=Automatic \
        DEVELOPMENT_TEAM="${TEAM_ID}" \
        2>&1 | tee "${LOG_DIR}/archive.log"
    
    if [ $? -eq 0 ]; then
        log "✅ Archive created: ${ARCHIVE_PATH}"
        echo "${ARCHIVE_PATH}" > "${BUILD_DIR}/.last_archive"
    else
        error "Archive failed. Check ${LOG_DIR}/archive.log for details."
    fi
}

# Export IPA for App Store
export_ipa() {
    log "Exporting IPA for App Store..."
    
    if [ ! -f "${BUILD_DIR}/.last_archive" ]; then
        error "No archive found. Run 'archive' first."
    fi
    
    ARCHIVE_PATH=$(cat "${BUILD_DIR}/.last_archive")
    EXPORT_PATH="${EXPORT_DIR}/$(date '+%Y%m%d_%H%M%S')"
    
    # Create export options plist
    cat > "${BUILD_DIR}/ExportOptions.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>teamID</key>
    <string>${TEAM_ID}</string>
    <key>uploadSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
    <key>destination</key>
    <string>upload</string>
</dict>
</plist>
EOF
    
    xcodebuild -exportArchive \
        -archivePath "${ARCHIVE_PATH}" \
        -exportPath "${EXPORT_PATH}" \
        -exportOptionsPlist "${BUILD_DIR}/ExportOptions.plist" \
        2>&1 | tee "${LOG_DIR}/export.log"
    
    if [ $? -eq 0 ]; then
        log "✅ IPA exported to: ${EXPORT_PATH}"
    else
        error "Export failed. Check ${LOG_DIR}/export.log for details."
    fi
}

# Upload to TestFlight
upload_testflight() {
    log "Uploading to TestFlight..."
    
    if [ -z "$APP_STORE_API_KEY" ] || [ -z "$APP_STORE_ISSUER_ID" ]; then
        warn "APP_STORE_API_KEY and APP_STORE_ISSUER_ID not set."
        log "You can upload manually using Xcode or Transporter app."
        return
    fi
    
    EXPORT_PATH=$(ls -td ${EXPORT_DIR}/*/ | head -1)
    IPA_PATH="${EXPORT_PATH}/${PROJECT_NAME}.ipa"
    
    if [ ! -f "${IPA_PATH}" ]; then
        error "IPA not found at ${IPA_PATH}"
    fi
    
    xcrun altool --upload-app \
        --type ios \
        --file "${IPA_PATH}" \
        --apiKey "${APP_STORE_API_KEY}" \
        --apiIssuer "${APP_STORE_ISSUER_ID}" \
        2>&1 | tee "${LOG_DIR}/upload.log"
    
    if [ $? -eq 0 ]; then
        log "✅ Successfully uploaded to TestFlight!"
    else
        error "Upload failed. Check ${LOG_DIR}/upload.log for details."
    fi
}

# Run tests
run_tests() {
    log "Running unit tests..."
    
    xcodebuild test \
        -project "${PROJECT_DIR}/${PROJECT_NAME}.xcodeproj" \
        -scheme "${SCHEME}" \
        -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
        2>&1 | tee "${LOG_DIR}/test.log"
    
    if [ $? -eq 0 ]; then
        log "✅ All tests passed!"
    else
        warn "Some tests failed. Check ${LOG_DIR}/test.log for details."
    fi
}

# Show build settings
show_settings() {
    log "Build Settings for ${PROJECT_NAME}:"
    echo ""
    xcodebuild -project "${PROJECT_DIR}/${PROJECT_NAME}.xcodeproj" \
        -scheme "${SCHEME}" \
        -showBuildSettings 2>/dev/null | grep -E "(PRODUCT_NAME|BUNDLE_IDENTIFIER|MARKETING_VERSION|DEVELOPMENT_TEAM|CODE_SIGN)"
}

# Print usage
usage() {
    echo ""
    echo -e "${BLUE}OrbitV3Full iOS Deployment Script${NC}"
    echo ""
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  setup       - Create build directories"
    echo "  clean       - Clean previous builds"
    echo "  build       - Build for iOS Release"
    echo "  simulator   - Build for iOS Simulator"
    echo "  archive     - Create archive for App Store"
    echo "  export      - Export IPA from archive"
    echo "  upload      - Upload to TestFlight"
    echo "  test        - Run unit tests"
    echo "  settings    - Show build settings"
    echo "  all         - Full pipeline: clean, build, archive, export"
    echo ""
    echo "Environment Variables:"
    echo "  APP_STORE_API_KEY    - App Store Connect API Key ID"
    echo "  APP_STORE_ISSUER_ID  - App Store Connect Issuer ID"
    echo ""
}

# Main
case "${1:-usage}" in
    setup)
        setup_directories
        ;;
    clean)
        clean_build
        ;;
    build)
        setup_directories
        build_release
        ;;
    simulator)
        setup_directories
        build_simulator
        ;;
    archive)
        setup_directories
        archive
        ;;
    export)
        export_ipa
        ;;
    upload)
        upload_testflight
        ;;
    test)
        run_tests
        ;;
    settings)
        show_settings
        ;;
    all)
        setup_directories
        clean_build
        build_release
        archive
        export_ipa
        log "🚀 Full build pipeline complete!"
        ;;
    *)
        usage
        ;;
esac
