# TestFlight Automation: AIgent vs BTCWidget Comparison

## Status

- **AIgent**: ✅ Working (Build 1.15 confirmed on device)
- **BTCWidget**: ✅ Working (historically worked, needs verification after recent changes)

---

## Configuration Comparison

### Fastfile: `upload_to_testflight()` Parameters

| Parameter | AIgent (Working) | BTCWidget (Working) | Notes |
|-----------|-----------------|---------------------|-------|
| `api_key` | ✅ Yes | ✅ Yes | Required for API auth |
| `skip_waiting_for_build_processing` | `false` | `false` | Both wait for processing |
| `uses_non_exempt_encryption` | `false` | `false` | Same |
| `distribute_external` | ❌ **Removed** | `false` | **Key difference** - BTCWidget explicitly sets, AIgent removed it |
| `notify_external_testers` | ❌ **Removed** | `false` | **Key difference** - BTCWidget explicitly sets, AIgent removed it |
| `groups` | ❌ **Removed** | ❌ Not present | **Critical**: Neither specifies groups - lets Apple auto-distribute |

**Key Learning**: Both working configs **do NOT specify `groups` parameter**. Apple automatically distributes to internal testers when `groups` is omitted.

### Fastfile: Version Bump Strategy

| Aspect | AIgent | BTCWidget |
|--------|--------|-----------|
| Version format | Major.Minor (e.g., 1.14) | Major.Minor.Build (e.g., 1.5.20260120223223) |
| Build number | Timestamp | Timestamp |
| Minor version | Auto-increment on each build | Auto-increment on each build |
| Git commit | ✅ Yes, locally only | ❌ No git operations |
| Git push | ❌ **Removed** (was causing infinite loop) | ❌ Not present |

**Key Learning**: Fastfile should **NEVER push to GitHub**. Version bumps should be local commits only or no commits at all.

### Watcher Script: Change Detection

| Feature | AIgent | BTCWidget |
|---------|--------|-----------|
| Detection method | `.last_built_commit` file | `git rev-parse HEAD` vs `origin/branch` |
| Tracks last build | ✅ Yes, in file | ❌ No, uses working tree state |
| Works from own directory | ✅ Yes | ❌ No - will miss changes if pushed from watcher dir |
| Default branch detection | ✅ Auto-detects main/master | ❌ No - assumes branch exists |
| Merge conflicts | ✅ `git reset --hard` before pull | ❌ Old stash/pop logic |
| Feature branch handling | ✅ Merges to main before building | ❌ No merge logic |

**Key Learning**: Using `.last_built_commit` file is **critical** for reliable detection when working in the same directory as the watcher.

### Watcher Script: Branch Handling

| Feature | AIgent | BTCWidget |
|---------|--------|-----------|
| Branch auto-detect | ✅ Finds most recent branch | ✅ Same |
| Default branch | ✅ Auto-detects main/master | ❌ Not implemented |
| Feature branch merge | ✅ Merges to main with `-X theirs` | ❌ No merge |
| Build branch | Always from `main` | From whatever branch has changes |

**Key Learning**: AIgent ensures all builds come from `main` branch. BTCWidget builds from whatever branch changed.

### App Configuration

| Aspect | AIgent | BTCWidget |
|--------|--------|-----------|
| Bundle ID | `com.doogan.AIgent` | `com.doogan.BTCWidget` |
| Extensions | None | ✅ Has widget extension |
| Provisioning profiles | 1 (app only) | 2 (app + extension) |
| Complexity | Simple single-target app | Multi-target with extension |

---

## What's Common (Required for Success)

### 1. ✅ No `groups` Parameter
Both working configs **omit** the `groups` parameter in `upload_to_testflight()`. This lets Apple automatically distribute to internal testers.

```ruby
# ✅ WORKING
upload_to_testflight(
  api_key: api_key,
  skip_waiting_for_build_processing: false,
  uses_non_exempt_encryption: false
)

# ❌ BROKEN
upload_to_testflight(
  groups: ["Dev Team"]  # ← This breaks auto-distribution
)
```

### 2. ✅ No Git Push from Fastfile
Neither working config pushes to GitHub during the build process. This prevents infinite loops.

- **AIgent**: Removed `git push origin HEAD` after discovering infinite loop
- **BTCWidget**: Never had git push in Fastfile

### 3. ✅ App Store Connect API Key
Both use API key authentication for automated uploads:
```ruby
api_key = app_store_connect_api_key(
  key_id: ENV["APP_STORE_CONNECT_API_KEY_KEY_ID"],
  issuer_id: ENV["APP_STORE_CONNECT_API_KEY_ISSUER_ID"],
  key_filepath: ENV["APP_STORE_CONNECT_API_KEY_KEY_FILEPATH"]
)
```

### 4. ✅ Watcher Auto-Detection
Both watchers automatically detect which branch has new changes:
```bash
LATEST_BRANCH=$(git for-each-ref --sort=-committerdate refs/remotes/origin \
  --format='%(refname:short)' | grep -v 'HEAD' | head -1 | sed 's|origin/||')
```

---

## What's Different (Explains Behavior Differences)

### 1. Change Detection Method

**AIgent** (More robust):
```bash
# Tracks last built commit in file
LAST_BUILT_COMMIT=$(cat .last_built_commit)
REMOTE_HEAD=$(git rev-parse "origin/$CURRENT_BRANCH")
if [ "$REMOTE_HEAD" != "$LAST_BUILT_COMMIT" ]; then
  # Build detected
fi
```

**BTCWidget** (Simpler but fragile):
```bash
# Compares working tree HEAD to remote
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse "origin/$CURRENT_BRANCH")
if [ "$LOCAL" != "$REMOTE" ]; then
  # Build detected
fi
```

**Impact**:
- AIgent works even when pushing from watcher's own directory
- BTCWidget will miss changes if you commit/push from its working directory

### 2. Branch Strategy

**AIgent**:
- Detects changes on any branch
- Merges feature branch → `main`
- Builds from `main` only
- Result: All builds tagged with `main` branch

**BTCWidget**:
- Detects changes on any branch
- Builds directly from that branch
- No automatic merge
- Result: Builds tagged with whatever branch changed

**Impact**: AIgent's approach ensures consistency - all TestFlight builds come from `main`.

### 3. Version Numbering

**AIgent**: `1.14` (Major.Minor)
- Simple, clean version numbers
- Minor increments each build

**BTCWidget**: `1.5.20260120223223` (Major.Minor.Timestamp)
- Very long version strings
- Timestamp provides unique identifier
- Can hit Apple's version string length limits

### 4. Provisioning Profiles

**AIgent**: Single profile
```ruby
provisioningProfiles: {
  "com.doogan.AIgent" => app_profile
}
```

**BTCWidget**: Multiple profiles (app + extension)
```ruby
provisioningProfiles: {
  "com.doogan.BTCWidget" => app_profile,
  "com.doogan.BTCWidget.BTCWidgetExtension" => extension_profile
}
```

**Impact**: BTCWidget has additional complexity managing widget extension signing.

---

## Lessons Learned

### Critical Success Factors

1. **DO NOT add `groups` parameter to `upload_to_testflight()`**
   - Apple auto-distributes to internal testers when omitted
   - Explicitly setting it breaks auto-distribution via API

2. **DO NOT push from Fastfile during build**
   - Creates infinite loop: build → commit → push → watcher detects → build
   - Version bumps should be local commits only or no commits

3. **USE `.last_built_commit` file for detection**
   - More reliable than HEAD comparison
   - Works regardless of where changes are pushed from
   - Prevents rebuilding same commit

4. **ENSURE builds come from default branch** (optional but recommended)
   - Provides consistency
   - Clear history of what's in TestFlight
   - Easier to track releases

5. **AUTO-DETECT default branch name**
   - Repos may use `main` or `master`
   - Hard-coding fails when branch doesn't exist

### Common Pitfalls

❌ **Adding explicit group assignment**
- Breaks Apple's auto-distribution
- Results in builds uploading but not appearing on devices

❌ **Pushing from Fastfile**
- Creates infinite build loops
- Watcher detects version bump commits as new changes

❌ **Using HEAD comparison for detection**
- Fails when pushing from watcher's working directory
- LOCAL == REMOTE so no changes detected

❌ **Not handling merge conflicts**
- Stash/pop creates conflict markers
- Better to force clean state with `git reset --hard`

---

## Recommendations for Future Projects

### Minimal Working Fastfile Template

```ruby
lane :beta_auto do
  # 1. Set up API key
  api_key = app_store_connect_api_key(
    key_id: ENV["APP_STORE_CONNECT_API_KEY_KEY_ID"],
    issuer_id: ENV["APP_STORE_CONNECT_API_KEY_ISSUER_ID"],
    key_filepath: ENV["APP_STORE_CONNECT_API_KEY_KEY_FILEPATH"],
    in_house: false
  )

  # 2. Get provisioning profiles
  app_profile = get_provisioning_profile(
    api_key: api_key,
    app_identifier: "com.your.app",
    platform: "ios"
  )

  # 3. Set build number to timestamp
  build_number = Time.now.strftime("%Y%m%d%H%M%S")
  increment_build_number(
    xcodeproj: "YourApp.xcodeproj",
    build_number: build_number
  )

  # 4. Optional: increment version
  # (AIgent does this, BTCWidget uses timestamp in version)

  # 5. Build
  build_app(
    scheme: "YourApp",
    configuration: "Release",
    export_method: "app-store",
    export_options: {
      signingStyle: "manual",
      teamID: "YOUR_TEAM_ID",
      provisioningProfiles: {
        "com.your.app" => app_profile
      }
    }
  )

  # 6. Upload - KEEP IT SIMPLE
  upload_to_testflight(
    api_key: api_key,
    skip_waiting_for_build_processing: false,
    uses_non_exempt_encryption: false
    # DO NOT ADD: groups, distribute_external, notify_external_testers
  )
end
```

### Minimal Working Watcher Template

```bash
#!/bin/bash
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHECK_INTERVAL=15
cd "$PROJECT_DIR"

# Track last built commit
LAST_BUILT_COMMIT_FILE="$PROJECT_DIR/.last_built_commit"
LAST_BUILT_COMMIT=$(cat "$LAST_BUILT_COMMIT_FILE" 2>/dev/null || echo "")

# Auto-detect default branch
if git show-ref --verify --quiet refs/remotes/origin/main; then
    DEFAULT_BRANCH="main"
elif git show-ref --verify --quiet refs/remotes/origin/master; then
    DEFAULT_BRANCH="master"
fi

while true; do
    sleep $CHECK_INTERVAL
    git fetch --all 2>/dev/null

    # Find most recent branch
    LATEST_BRANCH=$(git for-each-ref --sort=-committerdate refs/remotes/origin \
      --format='%(refname:short)' | grep -v 'HEAD' | head -1 | sed 's|origin/||')

    # Check for new commits
    REMOTE_HEAD=$(git rev-parse "origin/$LATEST_BRANCH" 2>/dev/null)

    if [ "$REMOTE_HEAD" != "$LAST_BUILT_COMMIT" ]; then
        echo "NEW CHANGES DETECTED!"

        # Force clean state
        git reset --hard HEAD
        git clean -fd

        # Pull changes
        git checkout "$LATEST_BRANCH"
        git pull --rebase origin "$LATEST_BRANCH"

        # If not on default branch, merge to it
        if [ "$LATEST_BRANCH" != "$DEFAULT_BRANCH" ]; then
            git checkout "$DEFAULT_BRANCH"
            git merge "$LATEST_BRANCH" -X theirs --no-edit
        fi

        # Build
        fastlane beta_auto

        # Update last built commit
        echo "$REMOTE_HEAD" > "$LAST_BUILT_COMMIT_FILE"
    fi
done
```

---

## Testing Checklist

When setting up automation for a new project:

- [ ] Fastfile has NO `groups` parameter
- [ ] Fastfile has NO `git push` commands
- [ ] Watcher uses `.last_built_commit` file
- [ ] Watcher auto-detects default branch
- [ ] Watcher uses `git reset --hard` before pulling
- [ ] API key environment variables are set
- [ ] Test: Push code change and verify build appears on device
- [ ] Test: Version bumps don't trigger infinite loops
- [ ] Test: Works when pushing from watcher's directory
- [ ] Document time from push to device (usually 5-10 minutes)

---

## Summary

**Both AIgent and BTCWidget work because they:**
1. Omit `groups` parameter (lets Apple auto-distribute)
2. Don't push from Fastfile (no infinite loops)
3. Use App Store Connect API keys
4. Wait for build processing to complete

**AIgent is more robust because it:**
1. Uses `.last_built_commit` file (works from any directory)
2. Auto-detects default branch (handles main/master)
3. Merges to default branch (all builds from main)
4. Forces clean state (handles conflicts better)

**BTCWidget works but has limitations:**
1. HEAD comparison fails if pushing from watcher directory
2. Builds from feature branches (less consistent)
3. Simpler logic (fewer features but also fewer things to break)
