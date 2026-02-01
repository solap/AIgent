---
description: Deploy the current version to TestFlight
---

Commit any uncommitted changes, push to GitHub, and trigger TestFlight deployment.

## Instructions

1. Check if there are uncommitted changes
2. If there are changes, create a commit with an appropriate message
3. Push to GitHub
4. **IMPORTANT**: After pushing, directly run `fastlane beta_auto` in the background to trigger deployment
   - This ensures deployment works from both phone and computer
   - The watcher only detects remote pushes from other machines
   - Running fastlane directly bypasses the watcher limitation
5. Inform user that build has started and they can monitor deploy.log
