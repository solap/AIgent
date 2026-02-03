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

# Detect the default branch (main or master)
DEFAULT_BRANCH=""
if git show-ref --verify --quiet refs/remotes/origin/main; then
    DEFAULT_BRANCH="main"
elif git show-ref --verify --quiet refs/remotes/origin/master; then
    DEFAULT_BRANCH="master"
else
    echo "ERROR: Could not detect default branch (main or master)"
    exit 1
fi

echo "========================================"
echo "   AIgent TestFlight Auto-Deploy"
echo "========================================"
echo "   Watching: $PROJECT_DIR"
echo "   Default branch: $DEFAULT_BRANCH"
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

    # Show countdown
    for i in $(seq $CHECK_INTERVAL -1 1); do
        printf "\r   Next check in %2ds | Last deploy: %s | Checks: %d   " "$i" "$LAST_DEPLOY" "$CHECK_COUNT"
        sleep 1
    done

    printf "\r   Checking for changes...                                              "

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
        git stash pop --quiet 2>/dev/null || true

        if [ $? -eq 0 ]; then
            LAST_COMMIT=$(git log -1 --oneline)

            # If not on default branch, merge to default branch first
            if [ "$CURRENT_BRANCH" != "$DEFAULT_BRANCH" ]; then
                echo ""
                echo "Merging $CURRENT_BRANCH to $DEFAULT_BRANCH..."
                git checkout "$DEFAULT_BRANCH"

                if [ $? -ne 0 ]; then
                    echo "❌ Failed to checkout $DEFAULT_BRANCH"
                    LAST_DEPLOY="CHECKOUT FAILED $(date '+%H:%M:%S')"
                    echo "$LAST_DEPLOY" > "$LAST_DEPLOY_FILE"
                    continue
                fi

                # Merge with -X theirs strategy: feature branch wins all conflicts
                git merge "$CURRENT_BRANCH" -X theirs --no-edit -m "Auto-merge $CURRENT_BRANCH to $DEFAULT_BRANCH"

                if [ $? -eq 0 ]; then
                    echo "Pushing $DEFAULT_BRANCH to remote..."
                    git push origin "$DEFAULT_BRANCH"
                    echo "✓ Merged and pushed to $DEFAULT_BRANCH"
                else
                    echo "❌ Merge failed even with auto-conflict resolution"
                    LAST_DEPLOY="MERGE FAILED $(date '+%H:%M:%S')"
                    echo "$LAST_DEPLOY" > "$LAST_DEPLOY_FILE"
                    git merge --abort
                    continue
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

            if [ $DEPLOY_EXIT_CODE -eq 0 ]; then
                # Extract version info from Xcode project
                VERSION=$(grep -A1 'MARKETING_VERSION' "$PROJECT_DIR/AIgent.xcodeproj/project.pbxproj" | grep -o '[0-9.]*' | head -1)
                BUILD=$(grep -A1 'CURRENT_PROJECT_VERSION' "$PROJECT_DIR/AIgent.xcodeproj/project.pbxproj" | grep -o '[0-9]*' | head -1)

                LAST_DEPLOY=$(date '+%Y-%m-%d %H:%M:%S')
                echo "$LAST_DEPLOY" > "$LAST_DEPLOY_FILE"

                echo ""
                echo "========================================"
                echo "$LAST_DEPLOY ✅ DEPLOY SUCCESSFUL!"
                echo "   Version: $VERSION ($BUILD)"
                echo "   Commit: $LAST_COMMIT"
                echo "   Processing on Apple servers (5-10 min)"
                echo "========================================"

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

                # Send macOS notification
                osascript -e "display notification \"Check deploy.log for details\" with title \"AIgent Deploy Failed\" sound name \"Basso\""
            fi
        else
            LAST_DEPLOY="PULL FAILED $(date '+%H:%M:%S')"
            echo "$LAST_DEPLOY" > "$LAST_DEPLOY_FILE"
            echo "$(date '+%Y-%m-%d %H:%M:%S') Git pull failed!"
        fi
        echo ""
    fi
    # Don't print "No changes" - just keep the countdown on one line
done
