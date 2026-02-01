# AIgent - Multi-LLM Chat Interface

A SwiftUI iOS app that provides a unified chat interface for multiple Large Language Model providers.

## Features

- **Multi-Provider Support**: Chat with models from OpenAI, Anthropic, Google, and Meta
- **Provider Selection**: Switch between providers with a simple segmented control
- **Model Selection**: Choose specific models for each provider
- **Clean Chat Interface**: Modern SwiftUI design with message bubbles
- **Message History**: Full conversation tracking with model/provider info
- **Automated TestFlight Deployment**: Push changes from phone, auto-deploy to TestFlight

## Supported Models

### OpenAI
- GPT-4
- GPT-4 Turbo
- GPT-3.5 Turbo

### Anthropic
- Claude 3.5 Sonnet
- Claude 3 Opus
- Claude 3 Haiku

### Google
- Gemini Pro
- Gemini Ultra

### Meta
- Llama 3
- Llama 2

## Development Workflow

This app uses an automated TestFlight deployment system:

1. **Make Changes on Phone**
   - Use Claude Code mobile to edit code
   - Commit changes locally
   - Push to GitHub (creates feature branch)

2. **Automatic Deployment**
   - Local watcher detects changes (~15 seconds)
   - Auto-merges to master
   - Builds and uploads to TestFlight
   - Apple processes build (10-30 minutes)
   - Update appears on phone

## Setup

See `DEPLOYMENT_SETUP.md` for complete setup instructions including:
- App Store Connect registration
- API key configuration
- Provisioning profiles
- Local watcher setup

## Technical Details

- **Platform**: iOS 17.0+
- **Framework**: SwiftUI
- **Bundle ID**: com.doogan.AIgent
- **Team**: Doogan LLC (55H878TG95)

## Current Status

🚧 **In Development** - API integrations are placeholders. Current version shows UI and provider selection but uses simulated responses.

## Files

- `AIgent/ContentView.swift` - Main chat interface
- `AIgent/Models.swift` - Provider and message models
- `fastlane/Fastfile` - Build automation
- `watch-and-deploy-testflight.sh` - Local deployment watcher

## Documentation

- `README.md` - This file
- `DEPLOYMENT_APPROACH.md` - Why we chose local watcher over GitHub Actions
- `DEPLOYMENT_SETUP.md` - Complete setup guide

## License

Copyright © 2026 Doogan LLC
