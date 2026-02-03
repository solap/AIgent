# TestFlight Automation Troubleshooting Log

## Timeline

### Working Period (Builds 1.9-1.12)
**Status**: Builds appeared automatically on phone
**Configuration**:
- Fastfile: Basic `upload_to_testflight` with no group assignment
- No `distribute_external`, `notify_external_testers`, or `groups` parameters
- Builds uploaded successfully and **automatically appeared** on phone

### Breaking Period (Build 1.7+)
**Status**: Builds upload but don't appear on phone
**What Changed**: Attempted to add explicit group assignment to automate distribution

---

## Attempt Log

### Attempt 1: Add testFlightInternalTestingOnly flag
**Theory**: Need to explicitly mark as internal testing
**Changes**: Added `testFlightInternalTestingOnly: true` to export_options
**Result**: ❌ Build uploaded but didn't appear on phone

### Attempt 2: Add distribute_external and groups
**Theory**: Need to explicitly assign to "Dev Team" group
**Changes**:
```ruby
upload_to_testflight(
  distribute_external: false,
  notify_external_testers: false,
  groups: ["Dev Team"]
)
```
**Result**: ❌ Error: "Builds cannot be assigned to this internal group. - Cannot add internal group to a build."
**Discovery**: Apple's TestFlight API doesn't support auto-assigning to internal groups via API

### Attempt 3: Fix watcher branch detection
**Theory**: Builds from feature branches don't auto-distribute
**Changes**: Updated watcher to detect and merge to main branch
**Result**: ❌ Watcher had hardcoded `master` branch but repo uses `main`
**Fix**: Added DEFAULT_BRANCH auto-detection

### Attempt 4: Add -X theirs merge strategy
**Theory**: Merge conflicts blocking builds
**Changes**: Added `-X theirs` to auto-resolve conflicts
**Result**: ❌ Created git conflict markers in files instead of resolving them

### Attempt 5: Fix watcher stash/pop logic
**Theory**: Stashed changes causing conflicts
**Changes**: Replaced stash/pop with `git reset --hard` and `git clean`
**Result**: ❌ Still had conflicts from previous attempts

### Attempt 6: Fix watcher detection logic
**Theory**: Watcher compares local HEAD to remote, but they're equal when pushing from watcher's own directory
**Changes**: Changed watcher to track last built commit in `.last_built_commit` file instead of comparing HEAD
**Result**: ✅ Watcher now detects changes correctly
**Discovery**: Watcher will NEVER detect changes if you push from its own working directory using HEAD comparison

### Attempt 7: Remove infinite loop
**Theory**: Fastfile pushes version bumps, triggering new builds infinitely
**Changes**: Removed `git push origin HEAD` from Fastfile version bump
**Result**: ✅ Infinite loop stopped
**Discovery**: Every build created a version bump commit which triggered another build

---

## Current Status (2026-02-02)

### ✅ WORKING - Full End-to-End Automation Achieved!

1. **Watcher detection**: Uses `.last_built_commit` file to track what was last built
2. **Build automation**: Builds trigger automatically when pushing to GitHub
3. **Upload**: Builds upload successfully to App Store Connect
4. **No infinite loops**: Version bumps commit locally only, don't trigger new builds
5. **Auto-distribution**: Builds automatically appear in TestFlight on phone (1-5 minutes)
6. **Build 1.15 confirmed working on device**

### ✅ Mystery Solved!

**The problem was NOT the Fastfile config. The problem was the `groups` parameter.**

**Working Fastfile** (builds 1.9-1.12, 1.15):
```ruby
upload_to_testflight(
  api_key: api_key,
  skip_waiting_for_build_processing: false,
  uses_non_exempt_encryption: false
)
```

**Broken Fastfile** (build 1.14):
```ruby
upload_to_testflight(
  api_key: api_key,
  skip_waiting_for_build_processing: false,
  uses_non_exempt_encryption: false,
  groups: ["Dev Team"]  # ← This breaks auto-distribution
)
```

**The solution**:
- Apple automatically distributes builds to internal testers
- Don't specify `groups`, `distribute_external`, or `notify_external_testers`
- Just upload with basic config and Apple handles the rest
- Builds appear on device 1-5 minutes after processing completes

---

## Key Learnings

### 1. Apple TestFlight API Limitations
- **Internal groups cannot be assigned via API** (confirmed by GitHub issue #22051)
- Error: "Builds cannot be assigned to this internal group"
- External testing groups CAN be automated

### 2. Watcher Architecture Issues
- **HEAD comparison doesn't work** when pushing from watcher's directory
- **Solution**: Track last built commit in separate file
- **Must use**: `git rev-parse origin/main` vs stored commit, not `HEAD` vs `origin/main`

### 3. Infinite Loop Causes
- **Never push from Fastfile during build**
- Any git push during build will trigger watcher to build again
- Version bumps must commit locally only

### 4. Merge Conflict Resolution
- **`-X theirs` doesn't work as expected** - creates conflict markers instead of auto-resolving
- **Better solution**: `git reset --hard` before pulling to force clean state
- Watcher directory should never have local modifications

---

## Next Steps / Options

### Option A: Accept Manual Step
1. Watcher builds and uploads automatically
2. User gets email from Apple
3. User opens App Store Connect and clicks "Add to Dev Team"
4. Build appears on phone

### Option B: Switch to External Testing
1. Create external testing group in App Store Connect
2. Update Fastfile to use external group (API supports this)
3. Builds will auto-distribute to external testers
4. Requires adding testers to external group

### Option C: Investigate Why 1.9-1.12 Worked
1. Check App Store Connect settings from that time
2. Look for any auto-distribution settings
3. Check if there's a "default group" concept
4. Review Apple's TestFlight documentation for changes

---

## Files Modified

### `.last_built_commit`
- Tracks SHA of last successfully built commit
- Updated after each successful build
- Prevents rebuilding same commit

### `watch-and-deploy-testflight.sh`
- Added DEFAULT_BRANCH auto-detection (main vs master)
- Changed detection logic to use `.last_built_commit` file
- Removed stash/pop, added `git reset --hard` before pulling
- Fixed to work regardless of where changes are pushed from

### `fastlane/Fastfile`
- Removed `git push origin HEAD` from version bump
- Removed `groups: ["Dev Team"]` parameter (causes API error)
- Removed `distribute_external` and `notify_external_testers` (don't help)
- Kept `testFlightInternalTestingOnly: true` in export_options

---

## Final Solution Summary

### The Working Configuration

**Fastfile** (`fastlane/Fastfile`):
```ruby
upload_to_testflight(
  api_key: api_key,
  skip_waiting_for_build_processing: false,
  uses_non_exempt_encryption: false
)
# DO NOT add: groups, distribute_external, notify_external_testers
```

**Watcher** (`watch-and-deploy-testflight.sh`):
- Tracks last built commit in `.last_built_commit` file
- Auto-detects default branch (main vs master)
- Discards local changes before pulling
- No git push during version bump

**Workflow**:
1. Make code changes
2. Type `/deploy` (commits and pushes to GitHub)
3. Watcher detects new commit (~15 seconds)
4. Watcher builds and uploads to TestFlight (~2-5 minutes)
5. Apple processes build (~1-5 minutes)
6. Build automatically appears in TestFlight app on phone
7. Total time: ~5-10 minutes from `/deploy` to device

### Critical Don'ts

❌ Don't add `groups: ["Dev Team"]` - breaks auto-distribution
❌ Don't add `distribute_external` or `notify_external_testers` - not needed
❌ Don't push from Fastfile during build - causes infinite loop
❌ Don't compare `git rev-parse HEAD` to remote - won't detect changes from same directory
❌ Don't use `-X theirs` merge strategy - creates conflict markers

### Critical Do's

✅ Use `.last_built_commit` file to track builds
✅ Let Apple auto-distribute to internal testers
✅ Commit version bumps locally only (no push)
✅ Use `git reset --hard` before pulling in watcher
✅ Auto-detect default branch name
