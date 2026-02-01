# AIgent Automated TestFlight Deployment Setup

## Goal
Automatically deploy iOS app to TestFlight when changes are pushed from phone, with zero manual intervention.

**Ideal workflow:**
1. Chat with Claude Code on phone
2. Make code changes
3. Push changes
4. Build happens automatically on desktop
5. App uploads to TestFlight
6. If build fails, check deploy.log
7. On success, merge to master automatically
8. Phone receives TestFlight update notification

## Prerequisites

### 1. Apple Developer Account
- Active Apple Developer Program membership ($99/year)
- Team: Doogan LLC (Team ID: 55H878TG95)

### 2. Desktop Mac Setup
- macOS with Xcode installed
- Xcode signed in with Apple ID
- Command line tools: `xcode-select --install`

### 3. Required Tools
```bash
# Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Fastlane
brew install fastlane

# Verify installation
fastlane --version
```

## Step 1: App Store Connect Setup

### Create App in App Store Connect
1. Go to https://appstoreconnect.apple.com
2. Click "My Apps" → "+" → "New App"
3. Fill in details:
   - **Platform**: iOS
   - **Name**: AIgent
   - **Primary Language**: English (U.S.)
   - **Bundle ID**: com.doogan.AIgent (must match Xcode project)
   - **SKU**: AIgent (can be anything unique)
   - **User Access**: Full Access

### Add Internal Tester (Yourself)
1. In App Store Connect → "TestFlight" tab
2. Click "Internal Testing" → "+"
3. Add yourself as internal tester
4. Accept invitation email on your phone

### Create App Store Connect API Key
1. Go to https://appstoreconnect.apple.com/access/api
2. Click "Keys" tab → "+" to create new key
3. Fill in:
   - **Name**: AIgent Fastlane
   - **Access**: App Manager or Developer
4. Click "Generate"
5. **IMPORTANT**: Download the `.p8` file immediately (can only download once)
6. Save the `.p8` file to `/Users/joeldehlin/projects/AIgent/secrets/AuthKey_XXXXXXXXXX.p8`
7. Note down:
   - **Key ID**: (e.g., 79UY843538)
   - **Issuer ID**: (e.g., 69a6de78-e798-47e3-e053-5b8c7c11a4d1)

## Step 2: Xcode Project Configuration

### Code Signing Settings
1. Open `AIgent.xcodeproj` in Xcode
2. Select project in navigator → "Signing & Capabilities" tab
3. For **AIgent** target:
   - Team: Doogan LLC
   - Bundle Identifier: com.doogan.AIgent
   - Signing: Automatic → **Manual** (important!)
   - Provisioning Profile: Will be downloaded by Fastlane

### Version Settings
1. In Xcode project settings:
   - **Version**: 1.0 (will auto-increment to 1.1, 1.2, etc.)
   - **Build**: 1 (will be replaced with timestamp)

## Step 3: Fastlane Configuration

### Create Fastlane Environment File
Create `/Users/joeldehlin/projects/AIgent/AIgent/fastlane/.env`:

```bash
# App Store Connect API Key
APP_STORE_CONNECT_API_KEY_KEY_ID="YOUR_KEY_ID"
APP_STORE_CONNECT_API_KEY_ISSUER_ID="YOUR_ISSUER_ID"
APP_STORE_CONNECT_API_KEY_KEY_FILEPATH="/Users/joeldehlin/projects/AIgent/secrets/AuthKey_XXXXXXXXXX.p8"

# App Configuration
SCHEME="AIgent"
```

Replace:
- `YOUR_KEY_ID` with Key ID from Step 1
- `YOUR_ISSUER_ID` with Issuer ID from Step 1
- `AuthKey_XXXXXXXXXX.p8` with actual filename

### Verify Fastlane Setup
```bash
cd /Users/joeldehlin/projects/AIgent/AIgent
fastlane beta_auto
```

If successful, you'll see:
- Build archive created
- Upload to App Store Connect
- Processing notification

## Step 4: Git Repository Setup

### Initialize Git
```bash
cd /Users/joeldehlin/projects/AIgent/AIgent
git init
git add .
git commit -m "Initial commit - AIgent multi-LLM chat app"
```

### Create GitHub Repository
```bash
# Using GitHub CLI (if installed)
gh repo create AIgent --public --source=. --remote=origin --push

# OR manually:
# 1. Go to https://github.com/new
# 2. Create repository "AIgent"
# 3. Run:
git remote add origin https://github.com/YOUR_USERNAME/AIgent.git
git branch -M master
git push -u origin master
```

## Step 5: Local Watcher Setup

### Create Secrets Directory
```bash
mkdir -p /Users/joeldehlin/projects/AIgent/secrets
# Copy your .p8 file here
```

### Set Environment Variables
Add to your shell profile (`~/.zshrc` or `~/.bash_profile`):

```bash
# AIgent TestFlight Deployment
export APP_STORE_CONNECT_API_KEY_KEY_ID="YOUR_KEY_ID"
export APP_STORE_CONNECT_API_KEY_ISSUER_ID="YOUR_ISSUER_ID"
export APP_STORE_CONNECT_API_KEY_KEY_FILEPATH="/Users/joeldehlin/projects/AIgent/secrets/AuthKey_XXXXXXXXXX.p8"
```

Then reload:
```bash
source ~/.zshrc  # or source ~/.bash_profile
```

### Start the Watcher
```bash
cd /Users/joeldehlin/projects/AIgent/AIgent
./watch-and-deploy-testflight.sh
```

You should see:
```
========================================
   AIgent TestFlight Auto-Deploy
========================================
   Watching: /Users/joeldehlin/projects/AIgent/AIgent
   Mode: All branches (auto-detect)
   Check interval: 15s
   Started: 2026-01-31 12:34:56
   Mode: Full automation (API key found)
   Press Ctrl+C to stop
========================================
```

## Step 6: Phone Setup

### Install Working Copy App
1. Download "Working Copy" from App Store (free)
2. Clone your AIgent repository
3. Configure git push credentials

### Install Claude Code Mobile
1. Follow Claude Code mobile setup instructions
2. Connect to your repository

### Make a Test Change
1. In Claude Code mobile, edit a Swift file (e.g., change a comment)
2. Commit and push changes
3. Watch your desktop terminal - should detect changes in ~15 seconds
4. Wait 2-5 minutes for build to complete
5. Wait 10-30 minutes for Apple processing
6. Check TestFlight app on phone for update

## Verification Checklist

- [ ] App created in App Store Connect
- [ ] You added as internal tester
- [ ] API key created and `.p8` file saved
- [ ] Fastlane `.env` file created with correct values
- [ ] Environment variables set in shell profile
- [ ] Git repository initialized and pushed to GitHub
- [ ] Watcher script running on desktop
- [ ] Working Copy app installed and repository cloned
- [ ] Test deployment completed successfully
- [ ] TestFlight update received on phone

## Troubleshooting

### "No API key found"
- Check that `.env` file exists in `fastlane/` directory
- Verify environment variables are set: `echo $APP_STORE_CONNECT_API_KEY_KEY_ID`
- Make sure `.p8` file path is correct

### "No profiles found"
- Fastlane will automatically download provisioning profiles
- Make sure you're using **manual signing** in Xcode
- Check that bundle ID matches App Store Connect

### "Build number already used"
- Should not happen with timestamp approach
- If it does, manually increment build number in Xcode

### "Upload limit reached"
- Apple limits TestFlight uploads per day
- Wait ~24 hours and try again

### Watcher not detecting changes
- Make sure you pushed to GitHub (not just committed locally)
- Check that watcher is running: `ps aux | grep watch-and-deploy`
- Verify git fetch works: `git fetch --all`

## Files and Directories

### Created Files
```
/Users/joeldehlin/projects/AIgent/
├── AIgent/
│   ├── AIgent/
│   │   ├── ContentView.swift
│   │   └── Models.swift
│   ├── fastlane/
│   │   ├── Fastfile
│   │   └── .env  (YOU MUST CREATE THIS)
│   ├── .gitignore
│   ├── watch-and-deploy-testflight.sh
│   ├── README.md
│   ├── DEPLOYMENT_APPROACH.md
│   └── DEPLOYMENT_SETUP.md (this file)
└── secrets/
    └── AuthKey_XXXXXXXXXX.p8  (YOU MUST ADD THIS)
```

### Ignored Files (in .gitignore)
- `*.ipa` - Build artifacts
- `*.dSYM.zip` - Debug symbols
- `*.mobileprovision` - Provisioning profiles
- `deploy.log` - Deployment logs
- `fastlane/report.xml` - Fastlane reports
- `fastlane/README.md` - Auto-generated docs
- `.env` - **CRITICAL**: Never commit API keys!

## Workflow Summary

Once everything is set up:

1. **On Phone**: Make code changes with Claude Code mobile
2. **On Phone**: Push to GitHub (creates feature branch)
3. **On Desktop**: Watcher detects changes automatically (~15s delay)
4. **On Desktop**: Build and upload happens automatically (2-5 min)
5. **On Apple**: Processing happens (10-30 min)
6. **On Phone**: TestFlight notification appears
7. **On Phone**: Install update and test

## Keeping Watcher Running

### Run in Background
```bash
cd /Users/joeldehlin/projects/AIgent/AIgent
./watch-and-deploy-testflight.sh &
```

### Check if Running
```bash
ps aux | grep watch-and-deploy-testflight.sh
```

### View Logs
```bash
tail -f /Users/joeldehlin/projects/AIgent/AIgent/deploy.log
```

### Stop Watcher
```bash
pkill -f watch-and-deploy-testflight.sh
```

## Next Steps

After successful setup:
1. Start implementing LLM API integrations (currently placeholders)
2. Test end-to-end workflow from phone
3. Iterate on features using automated deployment
4. Share TestFlight build with other testers if needed

## Support

See also:
- `DEPLOYMENT_APPROACH.md` - Why we chose this approach
- `README.md` - App overview and features
- `deploy.log` - Real-time deployment logs
