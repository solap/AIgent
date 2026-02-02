#!/bin/bash

# Deploy to TestFlight
# This script builds and uploads the app to TestFlight

echo "========================================"
echo "DEPLOYING TO TESTFLIGHT"
echo "========================================"
echo ""

PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$PROJECT_DIR"

DEPLOY_LOG="$PROJECT_DIR/deploy.log"

echo "Full logs: $DEPLOY_LOG"
echo ""

# Run fastlane
fastlane beta_auto > "$DEPLOY_LOG" 2>&1

DEPLOY_EXIT_CODE=$?

if [ $DEPLOY_EXIT_CODE -eq 0 ]; then
    echo ""
    echo "========================================"
    echo "✅ DEPLOY SUCCEEDED!"
    echo "========================================"
    echo ""

    # Send macOS notification
    osascript -e 'display notification "App uploaded to TestFlight successfully!" with title "AIgent Deploy Success" sound name "Glass"'
else
    echo ""
    echo "========================================"
    echo "❌ DEPLOY FAILED!"
    echo "   Exit code: $DEPLOY_EXIT_CODE"
    echo "   See full log: $DEPLOY_LOG"
    echo "========================================"
    echo ""
    echo "Error details:"
    tail -30 "$DEPLOY_LOG"

    # Send macOS notification
    osascript -e 'display notification "Check deploy.log for details" with title "AIgent Deploy Failed" sound name "Basso"'

    exit $DEPLOY_EXIT_CODE
fi
