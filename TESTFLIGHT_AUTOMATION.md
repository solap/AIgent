# TestFlight Auto-Distribution Troubleshooting Log

## Problem Statement
Builds 1.9-1.12 automatically appeared in TestFlight app after upload. Starting with build 1.2, builds stopped auto-distributing and required manual assignment to "Dev Team" group in App Store Connect.

## Root Cause (SOLVED)
**Missing `testFlightInternalTestingOnly: true` in Fastfile export options.**

This is an Xcode 15+ feature that marks builds for internal-only testing and triggers automatic distribution to internal tester groups.

## Solution That Worked

### Fastfile Changes
Added to `export_options` in `build_app`:
```ruby
testFlightInternalTestingOnly: true
```

Full working config:
```ruby
build_app(
  scheme: ENV["SCHEME"] || "AIgent",
  configuration: "Release",
  export_method: "app-store",
  export_options: {
    signingStyle: "manual",
    teamID: "55H878TG95",
    provisioningProfiles: {
      "com.doogan.AIgent" => app_profile
    },
    testFlightInternalTestingOnly: true  # <-- KEY FIX
  }
)

upload_to_testflight(
  api_key: api_key,
  skip_waiting_for_build_processing: false,
  uses_non_exempt_encryption: false,
  distribute_external: false,
  notify_external_testers: false,
  groups: ["Dev Team"]
)
```

### Evidence of Success
Build 1.7 deploy.log (line 185):
```
[23:53:24]: Successfully distributed build to Internal testers 🚀
```

This was the FIRST time we saw successful distribution after builds 1.2-1.6 all failed.

## What We Tried (That Didn't Work)

### Attempt 1: Add groups parameter alone
```ruby
upload_to_testflight(
  groups: ["Dev Team"]
)
```
**Result:** Failed with "Beta App Description is missing" error because `groups` parameter triggers beta app review submission which requires beta app localization setup.

### Attempt 2: Add skip_submission
```ruby
upload_to_testflight(
  groups: ["Dev Team"],
  skip_submission: true
)
```
**Result:** Silently skipped distribution entirely. No distribution happens with skip_submission.

### Attempt 3: Use distribute_external: false alone
```ruby
upload_to_testflight(
  distribute_external: false
)
```
**Result:** Build uploaded but not distributed to any group.

### Attempt 4: Combine distribute_external + groups
```ruby
upload_to_testflight(
  distribute_external: false,
  groups: ["Dev Team"]
)
```
**Result:** Still triggered beta app review submission, failed with "Beta App Description is missing"

## Other Issues Found & Fixed

### 1. Watcher Script Scrolling
**Problem:** Countdown was creating new lines instead of updating in place.

**Fix:** Changed from `printf "\r"` to `tput cr` and `tput el` for proper terminal control:
```bash
tput cr 2>/dev/null || echo -n $'\r'
tput el 2>/dev/null || true
echo -n "   Next check in ${i}s | Last deploy: $LAST_DEPLOY | Checks: $CHECK_COUNT"
```

### 2. Merge Conflicts in project.pbxproj
**Problem:** Fastlane bumps version numbers in project.pbxproj, causing conflicts when watcher merges feature branch to main.

**Fix:** Added auto-resolution to watcher script:
```bash
if git diff --name-only --diff-filter=U | grep -q "AIgent.xcodeproj/project.pbxproj"; then
    echo "   Resolving AIgent.xcodeproj/project.pbxproj (using incoming changes)..."
    git checkout --theirs AIgent.xcodeproj/project.pbxproj
    git add AIgent.xcodeproj/project.pbxproj
fi
```

### 3. Missing Automation-First Documentation
**Fix:** Added comprehensive "Automation-First Philosophy" section to `.claude/claude.md` with mandatory workflow for handling issues.

## Key Learnings

1. **App Store Connect Setting**: "Automatic for Xcode Builds" only applies to builds uploaded directly from Xcode, NOT fastlane API uploads.

2. **testFlightInternalTestingOnly**: This export option is the key to automatic internal distribution via API/fastlane. Without it, builds upload but don't auto-distribute.

3. **groups parameter triggers beta review**: Adding `groups: ["Dev Team"]` to `upload_to_testflight` triggers beta app review submission, which requires beta app localization even for internal groups.

4. **Fastfile location matters**: Changes to Fastfile must be on the machine where fastlane runs (desktop), not just pushed from phone.

## Testing Status

✅ **Build 1.7** - Successfully distributed with testFlightInternalTestingOnly
❌ **Build 1.7 DOES NOT appear in TestFlight app** - User confirmed build not visible
📧 **Apple emails received** - Both processing warning and success notification received

### Attempt 5: Build 1.7 with testFlightInternalTestingOnly (2026-02-01 23:50)
**Configuration:**
```ruby
export_options: {
  testFlightInternalTestingOnly: true
}
upload_to_testflight(
  skip_waiting_for_build_processing: false,
  uses_non_exempt_encryption: false,
  distribute_external: false,
  notify_external_testers: false,
  groups: ["Dev Team"]
)
```

**Result:** Build uploaded successfully. Deploy.log shows "Successfully distributed build to Internal testers 🚀". Apple sent confirmation emails. BUT build does NOT appear in TestFlight app on user's phone.

**Key Discovery:** Build 1.7 was built from **feature branch** `claude/fix-model-selection-chat-lw7Hv`, not from `main`. Watcher script attempted to merge to main but failed.

**Watcher Issues Found:**
1. Merge to main is failing (shows "MERGE FAILED AGAIN 23:28:41")
2. Script tries to checkout `master` branch which doesn't exist (repo uses `main`)
3. .claude/claude.md merge conflicts preventing successful merge
4. Builds are being created from feature branches instead of main branch

**Theory:** TestFlight may not be distributing builds from feature branches even though upload succeeds.

## Next Steps

1. **Fix watcher script** to properly detect and merge to `main` (not `master`)
2. **Add conflict resolution** for `.claude/` directory files
3. **Ensure builds are created from main branch** after successful merge
4. **Verify** build appears after deploying from main branch
5. **Document** if feature branch builds cannot auto-distribute to TestFlight

## References

- [fastlane Discussion #21525](https://github.com/fastlane/fastlane/discussions/21525) - TestFlight Internal Only support
- [fastlane Discussion #20640](https://github.com/fastlane/fastlane/discussions/20640) - Internal Group Testing Release Settings
- Xcode 15 introduced testFlightInternalTestingOnly option for faster internal testing
