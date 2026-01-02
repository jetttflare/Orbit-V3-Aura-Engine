# OrbitV3Full iOS Deployment Guide
# ==================================

## 📱 Project Configuration

| Setting | Value |
|---------|-------|
| **Product Name** | OrbitV3Full |
| **Bundle ID** | com.antigravity.orbitv3full |
| **Version** | 3.1.0 |
| **Build** | 1 |
| **Team ID** | 5DTUQN5C5R |
| **Minimum iOS** | 16.0 |
| **Devices** | iPhone, iPad |

---

## 🚀 Quick Deploy Commands

### Build for Simulator (Testing)
```bash
./scripts/deploy_ios.sh simulator
```

### Build for Device (Release)
```bash
./scripts/deploy_ios.sh build
```

### Full Pipeline (Archive + Export)
```bash
./scripts/deploy_ios.sh all
```

### Upload to TestFlight
```bash
export APP_STORE_API_KEY="YOUR_KEY_ID"
export APP_STORE_ISSUER_ID="YOUR_ISSUER_ID"
./scripts/deploy_ios.sh upload
```

---

## 📋 Pre-Deployment Checklist

### 1. Code Signing Setup
- [ ] Apple Developer account is active
- [ ] Xcode is signed in to your Apple ID
- [ ] Automatic signing is enabled (already configured)
- [ ] Team ID is correct: `5DTUQN5C5R`

### 2. App Store Connect Setup
- [ ] App record created in App Store Connect
- [ ] Bundle ID registered: `com.antigravity.orbitv3full`
- [ ] Screenshots prepared (6.7" and 5.5" minimum)
- [ ] App description and metadata ready
- [ ] Privacy policy URL available

### 3. Version Bump (Before Release)
```bash
# Current: MARKETING_VERSION = 3.1.0
# Update in Xcode project settings or:
cd /Users/jlow/Desktop/OrbitV3Full
sed -i '' 's/MARKETING_VERSION = 3.1.0/MARKETING_VERSION = 3.2.0/' OrbitV3Full.xcodeproj/project.pbxproj

# Bump build number
sed -i '' 's/CURRENT_PROJECT_VERSION = 1/CURRENT_PROJECT_VERSION = 2/' OrbitV3Full.xcodeproj/project.pbxproj
```

---

## 🔧 Manual Build Steps (Xcode)

### Build for Device
1. Open `OrbitV3Full.xcodeproj` in Xcode
2. Select scheme: **OrbitV3Full**
3. Select destination: **Any iOS Device (arm64)**
4. Product → Build (⌘B)

### Create Archive
1. Product → Archive
2. Wait for archive to complete
3. Archive will appear in Organizer (⌘⇧A)

### Export for App Store
1. In Organizer, select archive
2. Click **Distribute App**
3. Select **App Store Connect** → **Upload**
4. Follow prompts to upload

### Export for Ad Hoc Testing
1. In Organizer, select archive
2. Click **Distribute App**
3. Select **Ad Hoc**
4. Export IPA for device installation

---

## 🛠️ Build Pipeline (CI/CD)

### GitHub Actions Workflow
```yaml
# .github/workflows/ios.yml
name: iOS Build

on:
  push:
    branches: [main]
    tags: ['v*']

jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode.app
      
      - name: Build
        run: |
          xcodebuild build \
            -project OrbitV3Full.xcodeproj \
            -scheme OrbitV3Full \
            -configuration Release \
            -destination 'generic/platform=iOS Simulator' \
            CODE_SIGN_IDENTITY="" \
            CODE_SIGNING_REQUIRED=NO
      
      - name: Archive
        if: startsWith(github.ref, 'refs/tags/')
        run: |
          xcodebuild archive \
            -project OrbitV3Full.xcodeproj \
            -scheme OrbitV3Full \
            -configuration Release \
            -destination 'generic/platform=iOS' \
            -archivePath build/OrbitV3Full.xcarchive
```

---

## 📦 Build Artifacts

After running the deploy script, artifacts are located at:

```
build/
├── Archives/              # Xcode archives (.xcarchive)
│   └── OrbitV3Full_YYYYMMDD_HHMMSS.xcarchive
├── Export/                # Exported IPAs
│   └── YYYYMMDD_HHMMSS/
│       └── OrbitV3Full.ipa
├── Logs/                  # Build logs
│   ├── build.log
│   ├── archive.log
│   └── export.log
└── ExportOptions.plist    # Export configuration
```

---

## 🐛 Troubleshooting

### Build Fails: Code Signing
```bash
# Check available signing identities
security find-identity -v -p codesigning

# Check provisioning profiles
ls ~/Library/MobileDevice/Provisioning\ Profiles/
```

### Archive Fails: No Destination
```bash
# List available destinations
xcodebuild -showdestinations -project OrbitV3Full.xcodeproj -scheme OrbitV3Full
```

### Upload Fails: API Key
1. Create API key at [App Store Connect](https://appstoreconnect.apple.com/access/api)
2. Download the `.p8` file
3. Set environment variables:
```bash
export APP_STORE_API_KEY="XXXXXXXXXX"
export APP_STORE_ISSUER_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

---

## 📊 App Store Screenshots

Required screenshots for submission:

| Device | Size | Required |
|--------|------|----------|
| iPhone 6.7" | 1290 x 2796 | Yes |
| iPhone 6.5" | 1284 x 2778 | Optional |
| iPhone 5.5" | 1242 x 2208 | Yes |
| iPad 12.9" | 2048 x 2732 | If supporting iPad |

### Capture Screenshots
```bash
# Using Xcode Simulator
xcrun simctl io booted screenshot screenshot.png
```

---

## 🎯 Release Workflow

1. **Development** → Merge to `develop`
2. **Testing** → Build simulator, run tests
3. **Release Prep** → Bump version, create PR to `main`
4. **Archive** → Run `./scripts/deploy_ios.sh archive`
5. **Export** → Run `./scripts/deploy_ios.sh export`
6. **Upload** → Submit to TestFlight
7. **Test** → Internal/External testing
8. **Submit** → Submit for App Review
9. **Release** → Publish to App Store

---

*Last Updated: 2026-01-02*
*Orbit V3.1 - Aura Engine*
