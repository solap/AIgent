# AIgent - Automated Deployment Approach

## Goal
Completely automate development of mobile features and auto-deployment to TestFlight from iPhone.

## Chosen Approach: Local Watcher + Fastlane

### Why This Approach?
Based on lessons learned from BTC Widget project, we chose **local watcher monitoring git + Fastlane** for the following reasons:

1. **GitHub Actions Limitations**
   - Fastlane API key format/authentication issues in GitHub Actions runner
   - Would require interactive login which defeats automation purpose
   - Complex code signing setup in CI environment
   - Decision: Use local approach for TestFlight distribution

2. **Local Watcher Benefits**
   - Direct access to App Store Connect API key without authentication issues
   - Faster feedback loop (no GitHub Actions queue)
   - Can see build output in real-time
   - Simpler debugging when issues occur
   - Proven to work reliably with BTC Widget

## How It Works

### Architecture
```
Phone (Working Copy app)
  → Push to GitHub (creates feature branch)
  → Local watcher detects remote changes
  → Auto-pulls changes
  → Auto-merges to master
  → Fastlane builds & uploads to TestFlight
  → Apple processes build (10-30 min)
  → Auto-distributes to internal testers
  → Phone receives update notification
```

### Key Components

#### 1. Local Watcher (`watch-and-deploy-testflight.sh`)
**Location:** `/Users/joeldehlin/projects/AIgent/AIgent/watch-and-deploy-testflight.sh`

**What it does:**
- Monitors git repository for remote changes every 15 seconds
- Auto-detects new branches created from phone
- Switches tracking to new feature branches automatically
- Pulls changes when detected
- Merges feature branch to master
- Triggers Fastlane `beta_auto` lane
- Logs all output to `deploy.log`

**Configuration:**
- Check interval: 15 seconds
- Mode: All branches (auto-detect)
- Requires: App Store Connect API key environment variables

#### 2. Fastlane Lane (`beta_auto`)
**Location:** `/Users/joeldehlin/projects/AIgent/AIgent/fastlane/Fastfile`

**Critical settings:**
```ruby
# Timestamp-based build numbers (ensures uniqueness)
build_number = Time.now.strftime("%Y%m%d%H%M%S")
increment_build_number(
  xcodeproj: "AIgent.xcodeproj",
  build_number: build_number
)

# Version format: Major.Minor.Build (e.g., 1.5.20260131123456)
current_version = get_version_number(
  xcodeproj: "AIgent.xcodeproj",
  target: "AIgent"
)
version_parts = current_version.split('.')
minor_version = version_parts[1].to_i + 1
new_version = "#{version_parts[0]}.#{minor_version}.#{build_number}"

# Auto-distribution settings
upload_to_testflight(
  api_key: api_key,
  skip_waiting_for_build_processing: false,  # CRITICAL: Wait for Apple processing
  distribute_external: false,                # Internal testers only
  notify_external_testers: false,
  uses_non_exempt_encryption: false          # Auto-answer export compliance
)
```

**Why these settings matter:**
- `skip_waiting_for_build_processing: false` - THE KEY to auto-distribution. Without this, builds upload but don't distribute to testers
- Timestamp build numbers prevent "already used" errors
- Other flags ensure automatic processing without manual intervention

## Proven Solutions

### 1. Timestamp Build Numbers
```ruby
build_number = Time.now.strftime("%Y%m%d%H%M%S")
```
- Format: `20260131123456` (YYYYMMDDHHmmss)
- Guarantees unique build numbers across all branches
- No more version conflicts

### 2. Wait for Processing + Auto-Distribution
```ruby
skip_waiting_for_build_processing: false
```
- Fastlane waits for Apple to process the build (10-30 minutes)
- Automatically distributes to internal testers after processing
- Build appears on phone without manual intervention

### 3. Auto-Detecting Feature Branches
- Watcher monitors all branches, not just master
- Automatically switches to track new branches from phone
- Merges to master after pulling changes
- Enables seamless workflow from phone

### 4. Build Artifacts in .gitignore
Prevents merge conflicts by ignoring:
- `*.ipa`
- `*.app.dSYM.zip`
- `*.mobileprovision`
- `deploy.log`
- `fastlane/report.xml`
- `fastlane/README.md`

## Workflow from iPhone

1. **Make Changes in Working Copy App**
   - Edit Swift files
   - Commit changes locally

2. **Push to GitHub**
   - Working Copy creates new feature branch automatically
   - Format: `claude/description-xxxxx`

3. **Wait for Deployment**
   - Local watcher detects change (~15 seconds)
   - Build and upload (~2-5 minutes)
   - Apple processing (10-30 minutes)
   - Notification appears on phone
   - Open TestFlight to install update

## Monitoring Deployments

### Real-Time Monitoring
The watcher should be run in a visible terminal window:
```bash
cd /Users/joeldehlin/projects/AIgent/AIgent
./watch-and-deploy-testflight.sh
```

### Logs
Full deployment logs are written to:
```
/Users/joeldehlin/projects/AIgent/AIgent/deploy.log
```

### Key Output to Watch For

**Success Indicators:**
```
NEW CHANGES DETECTED!
Pulling changes...
Merging to master...
✓ Merged and pushed to master
BUILDING AND UPLOADING TO TESTFLIGHT
Successfully uploaded the new binary to App Store Connect
Waiting for processing on... build_version: 20260131123456
Build uploaded to TestFlight!
```

**Failure Indicators:**
```
❌ DEPLOY FAILED!
CONFLICT (modify/delete): [filename]
error: Merging is not possible because you have unmerged files
```

## Environment Setup

### Required Environment Variables
```bash
export APP_STORE_CONNECT_API_KEY_KEY_ID="your-key-id"
export APP_STORE_CONNECT_API_KEY_ISSUER_ID="your-issuer-id"
export APP_STORE_CONNECT_API_KEY_KEY_FILEPATH="/path/to/key.p8"
```

### Required Files
- App Store Connect API Key (`.p8` file)
- Provisioning profiles (downloaded automatically by Fastlane)
- Xcode project configured for manual signing

## Troubleshooting

### Build Not Appearing on Phone?
1. Check `deploy.log` for errors
2. Verify `skip_waiting_for_build_processing: false` in Fastfile
3. Check TestFlight app - build may be "Processing"
4. Wait 30 minutes - Apple processing can be slow

### Merge Conflicts?
1. Check `.gitignore` includes all build artifacts
2. Manually resolve conflicts: `git merge --abort`, fix, retry
3. Consider: Does this file need to be tracked?

### Watcher Not Detecting Changes?
1. Verify you're on correct branch: `git branch`
2. Check remote has changes: `git fetch && git log origin/master`
3. Restart watcher: Ctrl+C, then `./watch-and-deploy-testflight.sh`

### Build Number Errors?
- Should not happen with timestamp approach
- If it does, check that Fastfile has the timestamp code

## Known Issues

### Apple Upload Limit (Daily Quota)
**Problem:** `Upload limit reached. Please wait 1 day and try again.`
**Root Cause:** Apple limits TestFlight uploads per day to prevent abuse
**Solution:** Wait ~24 hours between upload attempts. This is an Apple restriction we cannot bypass.

## Future Improvements to Consider

1. **GitHub Actions for Non-TestFlight Tasks**
   - Could still use for linting, tests, etc.
   - Just not for TestFlight upload

2. **Notifications**
   - Add desktop notification when build completes (already implemented)
   - Email/Slack notification on success/failure

3. **Build Artifacts Cleanup**
   - Auto-delete old `.ipa`, `.dSYM` files
   - Keep last N builds only

4. **Multi-Device Testing**
   - Add more internal testers
   - Automatic distribution to team

## Key Learnings (from BTC Widget)

1. **Simplicity wins**: Local automation simpler than CI/CD for this use case
2. **Build numbers matter**: Timestamp format solves many issues
3. **Wait for processing**: Critical for auto-distribution to work
4. **Ignore build artifacts**: Prevents merge conflicts
5. **Real-time feedback**: Being able to see watcher output is valuable
