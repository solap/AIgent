---
description: Deploy the current version to TestFlight
---

Commit any uncommitted changes and push to GitHub. The desktop watcher automatically handles the build.

## Instructions

1. Check if there are uncommitted changes with `git status`
2. If there are changes:
   - Stage all changes: `git add -A`
   - Create a commit with a descriptive message about what changed
   - Push to current branch: `git push origin HEAD`
3. Inform user:
   - "✅ Changes pushed to GitHub"
   - "⏳ Watcher will detect changes in ~15 seconds"
   - "🔨 Build will start automatically (2-5 min)"
   - "📱 TestFlight notification in 10-30 min after build completes"

## How It Works

- **Desktop watcher** (`watch-and-deploy-testflight.sh`) monitors GitHub for pushes
- **Watcher automatically:**
  - Detects your push within 15 seconds
  - Merges feature branch to `main` (with auto-conflict resolution)
  - Builds from `main` branch using fastlane
  - Uploads to TestFlight with automatic distribution
- **You don't need to:**
  - Run fastlane manually
  - Merge branches manually
  - Open Xcode
  - Do anything in App Store Connect

## Important

- This command ONLY pushes to GitHub
- Never attempts to run fastlane (that's the watcher's job)
- Works from any environment (phone, tablet, desktop)
- Desktop watcher must be running for builds to happen
