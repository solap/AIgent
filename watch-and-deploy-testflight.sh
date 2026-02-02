#!/bin/bash

# AIgent Auto-Deploy to TestFlight
# Watches for git changes and auto-deploys to TestFlight

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHECK_INTERVAL=15  # seconds

cd "$PROJECT_DIR"

# Load last deploy time from file if it exists
LAST_DEPLOY_FILE="$PROJECT_DIR/.last_deploy"
if [ -f "$LAST_DEPLOY_FILE" ]; then
    LAST_DEPLOY=$(cat "$LAST_DEPLOY_FILE")
else
    LAST_DEPLOY="Never"
fi

LAST_COMMIT=""
CHECK_COUNT=0
CURRENT_BRANCH=""

# Check if API key is configured for full automation
API_KEY_CONFIGURED=false
if [ -n "$APP_STORE_CONNECT_API_KEY_KEY_ID" ] || grep -q "APP_STORE_CONNECT_API_KEY_KEY_ID" fastlane/.env 2>/dev/null; then
    API_KEY_CONFIGURED=true
fi

echo "========================================"
echo "   AIgent TestFlight Auto-Deploy"
echo "========================================"
echo "   Watching: $PROJECT_DIR"
echo "   Mode: All branches (auto-detect)"
echo "   Check interval: ${CHECK_INTERVAL}s"
echo "   Started: $(date '+%Y-%m-%d %H:%M:%S')"
if [ "$API_KEY_CONFIGURED" = true ]; then
    echo "   Mode: Full automation (API key found)"
else
    echo "   Mode: Archive only (set up API key for full automation)"
    echo "   See: DEPLOYMENT_SETUP.md"
fi
echo "   Press Ctrl+C to stop"
echo "========================================"
echo ""

while true; do
    CHECK_COUNT=$((CHECK_COUNT + 1))

    # Show countdown (use tput for better terminal compatibility)
    for i in $(seq $CHECK_INTERVAL -1 1); do
        tput cr 2>/dev/null || echo -n $'\r'
        tput el 2>/dev/null || true
        echo -n "   Next check in ${i}s | Last deploy: $LAST_DEPLOY | Checks: $CHECK_COUNT"
        sleep 1
    done

    tput cr 2>/dev/null || echo -n $'\r'
    tput el 2>/dev/null || true
    echo -n "   Checking for changes..."

    # Fetch all branches from remote
    git fetch --all 2>/dev/null

    # Find the most recently updated remote branch
    LATEST_BRANCH=$(git for-each-ref --sort=-committerdate refs/remotes/origin --format='%(refname:short)' | grep -v 'HEAD' | head -1 | sed 's|origin/||')

    # If we detected a new branch, switch to it
    if [ "$LATEST_BRANCH" != "$CURRENT_BRANCH" ]; then
        CURRENT_BRANCH="$LATEST_BRANCH"
        printf "\n\n   Switched to tracking branch: $CURRENT_BRANCH\n"
    fi

    # Check if there are new commits on the current branch
    LOCAL=$(git rev-parse HEAD 2>/dev/null)
    REMOTE=$(git rev-parse "origin/$CURRENT_BRANCH" 2>/dev/null)

    if [ "$LOCAL" != "$REMOTE" ]; then
        # Check if the only changes are to build-status.json or .claude/ (avoid infinite loop and unnecessary builds)
        CHANGED_FILES=$(git diff --name-only HEAD..origin/$CURRENT_BRANCH 2>/dev/null)

        # Filter out .claude/ and build-status.json
        CODE_CHANGES=$(echo "$CHANGED_FILES" | grep -v "^\.claude/" | grep -v "^build-status\.json$")

        if [ -z "$CODE_CHANGES" ]; then
            # Only non-code files changed (build-status.json or .claude/*) - just pull and skip build
            git pull --rebase origin "$CURRENT_BRANCH" --quiet 2>/dev/null
            continue
        fi

        printf "\n"  # Only newline when we have changes
        echo ""
        echo "========================================"
        echo "$(date '+%Y-%m-%d %H:%M:%S') NEW CHANGES DETECTED!"
        echo "========================================"
        echo "   Local:  ${LOCAL:0:8}"
        echo "   Remote: ${REMOTE:0:8}"

        # Show what changed
        echo ""
        echo "Branch: $CURRENT_BRANCH"
        echo "New commits:"
        git log --oneline HEAD..origin/$CURRENT_BRANCH 2>/dev/null | head -5
        echo ""

        # Pull changes
        echo "Pulling changes..."

        # Stash any local changes to avoid conflicts
        git stash --quiet 2>/dev/null

        git checkout "$CURRENT_BRANCH" 2>/dev/null || git checkout -b "$CURRENT_BRANCH" origin/"$CURRENT_BRANCH" 2>/dev/null
        git pull --rebase origin "$CURRENT_BRANCH"

        # Reapply stashed changes if any
        if git stash pop --quiet 2>/dev/null; then
            # Check for conflicts in fastlane/Fastfile specifically
            if git diff --name-only --diff-filter=U | grep -q "fastlane/Fastfile"; then
                echo "⚠️  Conflict detected in Fastfile - auto-resolving by preferring remote version..."
                git checkout --theirs fastlane/Fastfile
                git add fastlane/Fastfile
                echo "✓ Fastfile conflict resolved (used remote version)"
            fi
        fi

        if [ $? -eq 0 ]; then
            # Check if recovering from a merge failure
            if [[ "$LAST_DEPLOY" == MERGE\ FAILED* ]] || [[ "$LAST_DEPLOY" == MERGE\ RETRY* ]]; then
                LAST_DEPLOY="MERGE RETRY $(date '+%H:%M:%S')"
                echo "$LAST_DEPLOY" > "$LAST_DEPLOY_FILE"
            fi

            LAST_COMMIT=$(git log -1 --oneline)

            # If not on master, merge to master first
            if [ "$CURRENT_BRANCH" != "master" ] && [ "$CURRENT_BRANCH" != "main" ]; then
                echo ""
                echo "Merging $CURRENT_BRANCH to master..."
                git checkout master 2>/dev/null || git checkout main 2>/dev/null
                git merge "$CURRENT_BRANCH" --no-edit -m "Auto-merge $CURRENT_BRANCH to master"

                if [ $? -ne 0 ]; then
                    # Merge failed - check for common conflicts we can auto-resolve
                    echo "⚠️  Merge conflict detected - attempting auto-resolution..."

                    # Auto-resolve project.pbxproj conflicts (version bumps from fastlane)
                    if git diff --name-only --diff-filter=U | grep -q "AIgent.xcodeproj/project.pbxproj"; then
                        echo "   Resolving AIgent.xcodeproj/project.pbxproj (using incoming changes)..."
                        git checkout --theirs AIgent.xcodeproj/project.pbxproj
                        git add AIgent.xcodeproj/project.pbxproj
                    fi

                    # Auto-resolve Fastfile conflicts
                    if git diff --name-only --diff-filter=U | grep -q "fastlane/Fastfile"; then
                        echo "   Resolving fastlane/Fastfile (using incoming changes)..."
                        git checkout --theirs fastlane/Fastfile
                        git add fastlane/Fastfile
                    fi

                    # Check if all conflicts are resolved
                    REMAINING_CONFLICTS=$(git diff --name-only --diff-filter=U | wc -l | tr -d ' ')
                    if [ "$REMAINING_CONFLICTS" = "0" ]; then
                        echo "✓ All conflicts auto-resolved, completing merge..."
                        git commit --no-edit
                        echo "Pushing master to remote..."
                        git push origin master 2>/dev/null || git push origin main 2>/dev/null
                        echo "✓ Merged and pushed to master"
                    else
                        echo "❌ Merge failed - unresolved conflicts remain:"
                        git diff --name-only --diff-filter=U
                        git merge --abort
                        # Check if this is a repeated failure
                        if [[ "$LAST_DEPLOY" == MERGE\ FAILED* ]] || [[ "$LAST_DEPLOY" == MERGE\ RETRY* ]]; then
                            LAST_DEPLOY="MERGE FAILED AGAIN $(date '+%H:%M:%S')"
                        else
                            LAST_DEPLOY="MERGE FAILED $(date '+%H:%M:%S')"
                        fi
                        echo "$LAST_DEPLOY" > "$LAST_DEPLOY_FILE"
                        continue
                    fi
                else
                    echo "Pushing master to remote..."
                    git push origin master 2>/dev/null || git push origin main 2>/dev/null
                    echo "✓ Merged and pushed to master"
                fi
            fi

            # Deploy to TestFlight
            echo ""
            DEPLOY_LOG="$PROJECT_DIR/deploy.log"

            if [ "$API_KEY_CONFIGURED" = true ]; then
                echo ""
                echo "========================================"
                echo "BUILDING AND UPLOADING TO TESTFLIGHT"
                echo "========================================"
                echo "Full logs: $DEPLOY_LOG"
                echo ""

                # Run fastlane and show progress without scrolling
                cd "$PROJECT_DIR" && fastlane beta_auto > "$DEPLOY_LOG" 2>&1 &
                FASTLANE_PID=$!

                # Show progress while building
                while kill -0 $FASTLANE_PID 2>/dev/null; do
                    LAST_LINE=$(tail -1 "$DEPLOY_LOG" 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | cut -c1-80)
                    printf "\r%-80s" "$LAST_LINE"
                    sleep 1
                done
                wait $FASTLANE_PID
                DEPLOY_EXIT_CODE=$?
                printf "\n"
            else
                echo "Archiving for TestFlight..."
                cd "$PROJECT_DIR" && fastlane archive > "$DEPLOY_LOG" 2>&1
                DEPLOY_EXIT_CODE=$?
                echo ""
                echo "========================================"
                echo "MANUAL STEP REQUIRED:"
                echo "1. Xcode Organizer should open automatically"
                echo "2. Select the latest archive"
                echo "3. Click 'Distribute App' -> 'App Store Connect' -> 'Upload'"
                echo ""
                echo "To enable full automation, set up an API key."
                echo "See: DEPLOYMENT_SETUP.md"
                echo "========================================"
            fi

            # Extract version info from Xcode project
            VERSION=$(grep -A1 'MARKETING_VERSION' "$PROJECT_DIR/AIgent.xcodeproj/project.pbxproj" | grep -o '[0-9.]*' | head -1)
            BUILD=$(grep -A1 'CURRENT_PROJECT_VERSION' "$PROJECT_DIR/AIgent.xcodeproj/project.pbxproj" | grep -o '[0-9]*' | head -1)
            COMMIT_HASH=$(git rev-parse HEAD 2>/dev/null)
            COMMIT_MSG=$(git log -1 --pretty=%s 2>/dev/null)
            BUILD_STATUS_FILE="$PROJECT_DIR/build-status.json"

            if [ $DEPLOY_EXIT_CODE -eq 0 ]; then
                LAST_DEPLOY=$(date '+%Y-%m-%d %H:%M:%S')
                echo "$LAST_DEPLOY" > "$LAST_DEPLOY_FILE"

                echo ""
                echo "========================================"
                echo "$LAST_DEPLOY ✅ DEPLOY SUCCESSFUL!"
                echo "   Version: $VERSION ($BUILD)"
                echo "   Commit: $LAST_COMMIT"
                echo "   Processing on Apple servers (5-10 min)"
                echo "========================================"

                # Write build status to JSON for remote monitoring
                cat > "$BUILD_STATUS_FILE" << EOF
{
  "status": "success",
  "timestamp": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "version": "$VERSION",
  "build": "$BUILD",
  "branch": "$CURRENT_BRANCH",
  "commit": "$COMMIT_HASH",
  "commit_message": "$COMMIT_MSG",
  "error": null
}
EOF

                # Send macOS notification
                osascript -e "display notification \"Version $VERSION ($BUILD) uploaded successfully\" with title \"AIgent TestFlight Success\" sound name \"Glass\""
            else
                LAST_DEPLOY="❌ FAILED $(date '+%H:%M:%S')"
                echo "$LAST_DEPLOY" > "$LAST_DEPLOY_FILE"
                echo ""
                echo "========================================"
                echo "$(date '+%Y-%m-%d %H:%M:%S') ❌ DEPLOY FAILED!"
                echo "   Exit code: $DEPLOY_EXIT_CODE"
                echo "   See full log: $DEPLOY_LOG"
                echo "========================================"
                echo ""
                echo "Error details:"
                tail -30 "$DEPLOY_LOG"

                # Capture last 50 lines of error log for JSON
                ERROR_LOG=$(tail -50 "$DEPLOY_LOG" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')

                # Write build status to JSON for remote monitoring
                cat > "$BUILD_STATUS_FILE" << EOF
{
  "status": "failed",
  "timestamp": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "version": "$VERSION",
  "build": "$BUILD",
  "branch": "$CURRENT_BRANCH",
  "commit": "$COMMIT_HASH",
  "commit_message": "$COMMIT_MSG",
  "exit_code": $DEPLOY_EXIT_CODE,
  "error": "$ERROR_LOG"
}
EOF

                # Send macOS notification
                osascript -e "display notification \"Check deploy.log for details\" with title \"AIgent Deploy Failed\" sound name \"Basso\""
            fi

            # Push build status to repo for remote monitoring
            echo ""
            echo "Pushing build status to repo..."
            git add "$BUILD_STATUS_FILE"
            git commit -m "Build status: $([ $DEPLOY_EXIT_CODE -eq 0 ] && echo 'SUCCESS' || echo 'FAILED') - $VERSION ($BUILD)"
            # Push to the actual current branch (may be master after merge)
            ACTUAL_BRANCH=$(git rev-parse --abbrev-ref HEAD)
            git push origin "$ACTUAL_BRANCH" || echo "Warning: Failed to push build status"
            echo "Build status pushed to repo"
        else
            LAST_DEPLOY="PULL FAILED $(date '+%H:%M:%S')"
            echo "$LAST_DEPLOY" > "$LAST_DEPLOY_FILE"
            echo "$(date '+%Y-%m-%d %H:%M:%S') Git pull failed!"
        fi
        echo ""
    fi
    # Don't print "No changes" - just keep the countdown on one line
done
