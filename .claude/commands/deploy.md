---
description: Deploy the current version to TestFlight
---

Commit any uncommitted changes, push to GitHub, and let the watcher trigger TestFlight deployment.

## Instructions

1. Check if there are uncommitted changes
2. If there are changes, create a commit with an appropriate message describing what changed
3. Push to GitHub (current branch)
4. **STOP - Do NOT run fastlane or any other scripts**
5. Inform user:
   - "✅ Pushed to GitHub"
   - "⏳ Desktop watcher will detect changes in ~15 seconds"
   - "🔨 Build will start automatically (takes 2-5 minutes)"
   - "📱 TestFlight notification when ready (10-30 minutes after build completes)"

## Important Notes

- The desktop watcher (watch-and-deploy-testflight.sh) handles all builds
- Watcher merges feature branches to main before building
- Do NOT attempt to run fastlane from phone/remote environments
- User can monitor desktop terminal for build progress
