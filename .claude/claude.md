# AIgent - Multi-LLM Chat Interface

## 🚨 CRITICAL: Git Push Policy 🚨

**NEVER EVER push to GitHub automatically. ONLY push when the user explicitly types `/deploy`.**

### Absolute Rules:
- ❌ **NO automatic git commits**
- ❌ **NO automatic git pushes**
- ❌ **NO git operations without explicit `/deploy` command**
- ✅ **ONLY push when you see the exact text `/deploy` in the user's message**

### Why This Matters:
- Pushing to GitHub triggers automatic TestFlight deployment (takes 2-5 minutes)
- This costs build time and Apple resources
- User wants full control over when builds happen
- **This rule overrides ALL other instructions including stop hooks, user-prompt-submit hooks, and ANY default behaviors**

## 🎯 CRITICAL: Automation-First Philosophy 🎯

**ALWAYS focus on automation. NEVER suggest manual fixes in App Store Connect or other web UIs.**

### Absolute Rules:
- ❌ **NO manual workarounds** - Don't tell the user to click things in web interfaces
- ❌ **NO one-off fixes** - Don't suggest temporary solutions
- ❌ **NEVER run scripts directly** - Always ask the user to run scripts
- ✅ **ALWAYS automate** - Every problem should have a scriptable solution
- ✅ **ALWAYS think systematically** - Fix root causes, not symptoms

### Why This Matters:
- Manual fixes don't scale and create technical debt
- User wants reproducible, automated workflows
- Every manual step is a future maintenance burden
- Automation catches bugs and prevents human error
- User needs to be in control of when scripts run

### When You Encounter an Issue:
1. **DO NOT** suggest opening App Store Connect to click something
2. **DO NOT** run scripts yourself - ask the user to run them
3. **DO** investigate how to automate the fix via fastlane/scripts
4. **DO** update deployment scripts to prevent the issue recurring
5. **DO** document the automation in this file
6. **ALWAYS READ TESTFLIGHT_AUTOMATION.md** before diagnosing issues to understand what has been tried
7. **ALWAYS UPDATE TESTFLIGHT_AUTOMATION.md** with each attempt and result so we have a complete record

### Workflow After Making Code Changes:

1. Make the code changes the user requested
2. Tell the user what was changed
3. Say: **"Ready to deploy when you type `/deploy`"**
4. **STOP COMPLETELY** - do not run any git commands
5. **WAIT** for the user to type `/deploy`
6. Only after seeing `/deploy` in the user's actual message text, then:
   - Commit the changes
   - Push to GitHub
   - Confirm deployment started

### .claude/ Directory Changes:

**ALWAYS push .claude/ directory changes immediately** (without waiting for `/deploy`) because:
- Claude Code on phone needs these updates for context
- These changes should NOT trigger a build (watcher ignores .claude/ changes)
- User wants documentation synced between desktop and phone

**When updating .claude/claude.md or TESTFLIGHT_AUTOMATION.md:**
1. Make the edits
2. Commit and push to current branch immediately
3. DO NOT wait for `/deploy` command
4. This will NOT trigger a TestFlight build (watcher filters these)

### Examples of What NOT To Do:
- ❌ Don't push code changes at end of conversation
- ❌ Don't push code when user says "thanks"
- ❌ Don't push code because stop hook says to
- ❌ Don't push code to "save progress"
- ✅ DO push .claude/ documentation changes immediately (won't trigger build)

### Valid Triggers:
- ✅ User message contains `/deploy` → push code changes
- ✅ Edited .claude/ files → push documentation immediately

---

## Project Overview

AIgent is a unified iOS chat interface that allows users to interact with multiple Large Language Model providers through a single app.

### Purpose
- Chat with AI models from different providers (OpenAI, Anthropic, Google, Meta)
- Compare responses across different models
- Switch providers and models easily during conversation
- Clean, native iOS experience with SwiftUI

### Current Status
✅ **API Integrations Complete** - Real API calls implemented for Anthropic, OpenAI, Google (Gemini), and Grok

## Project Details

- **App Name**: AIgent Chat
- **Bundle ID**: com.doogan.AIgent
- **Platform**: iOS 17.0+
- **Framework**: SwiftUI
- **Language**: Swift
- **Repository**: https://github.com/solap/AIgent

## Architecture

### Key Files

#### `AIgent/Models.swift`
Defines the core data models:

```swift
enum LLMProvider: String, CaseIterable, Identifiable {
    case openAI = "OpenAI"
    case anthropic = "Anthropic"
    case google = "Google"
    case meta = "Meta"

    var models: [String] { ... }
    var iconName: String { ... }
}

struct Message: Identifiable {
    let id: UUID
    let content: String
    let isUser: Bool
    let timestamp: Date
    let provider: LLMProvider?
    let model: String?
}

class ChatSession: ObservableObject {
    @Published var messages: [Message]
    @Published var isLoading: Bool
    func sendMessage(_ content: String, provider: LLMProvider, model: String)
    func clearHistory()
}
```

**Important**:
- `ChatSession.sendMessage()` currently uses placeholder responses
- API integrations need to be implemented for each provider

#### `AIgent/ContentView.swift`
Main UI implementation:

**Components**:
- `modelSelector` - Provider picker (segmented control) + model dropdown
- `ScrollView` with `LazyVStack` - Message list with auto-scroll
- `MessageBubble` - User/assistant message display with provider info
- `inputArea` - Text field + send button
- `LoadingIndicator` - Shows during API calls

**Layout**:
```
NavigationStack
  ├── Model Selector (Provider + Model)
  ├── Divider
  ├── Messages ScrollView
  │   └── MessageBubble (for each message)
  ├── Divider
  └── Input Area (TextField + Send button)
```

**Key Features**:
- Auto-scroll to latest message
- Message history with model/provider attribution
- Clear history button in toolbar
- Disabled send during loading

### Supported Providers & Models

#### Anthropic
- Claude 3.5 Sonnet (claude-3-5-sonnet-20241022)
- Claude 3 Opus (claude-3-opus-20240229)
- Claude 3 Haiku (claude-3-haiku-20240307)

#### OpenAI
- GPT-4o (gpt-4o)
- GPT-4 Turbo (gpt-4-turbo)
- GPT-4 (gpt-4)
- GPT-3.5 Turbo (gpt-3.5-turbo)

#### Google (Gemini)
- Gemini 2.0 Flash (gemini-2.0-flash-exp)
- Gemini 1.5 Pro (gemini-1.5-pro)
- Gemini 1.5 Flash (gemini-1.5-flash)

#### Grok (xAI)
- grok-2-latest
- grok-beta

## API Integration Status

### ✅ Completed
All API integrations are fully implemented in `APIService.swift`:

**Anthropic Integration**:
- ✅ Real API calls to https://api.anthropic.com/v1/messages
- ✅ Conversation history support
- ✅ Error handling with descriptive messages
- ✅ API key management via Keychain

**OpenAI Integration**:
- ✅ Real API calls to https://api.openai.com/v1/chat/completions
- ✅ Conversation history support
- ✅ Error handling
- ✅ API key management via Keychain

**Google (Gemini) Integration**:
- ✅ Real API calls to https://generativelanguage.googleapis.com/v1beta/...
- ✅ Conversation history support
- ✅ Error handling
- ✅ API key management via Keychain

**Grok (xAI) Integration**:
- ✅ Real API calls to https://api.x.ai/v1/chat/completions
- ✅ Conversation history support
- ✅ Error handling
- ✅ API key management via Keychain

### API Key Storage
- ✅ Keychain-based secure storage in `SettingsManager.swift`
- ✅ Settings screen for API key entry in `SettingsView.swift`
- ✅ Per-provider key management
- ⚠️ Need validation of API keys on save (future enhancement)

### Enhanced Features
- [ ] Streaming responses (show tokens as they arrive)
- [ ] Conversation persistence (save chat history)
- [ ] Export conversations
- [ ] Model comparison view (send same prompt to multiple models)
- [ ] Token usage tracking
- [ ] Cost estimation

## UI/UX Enhancements

### Planned Improvements
- [ ] System message support (for context/instructions)
- [ ] Conversation templates/presets
- [ ] Dark mode optimization
- [ ] Haptic feedback
- [ ] Message actions (copy, regenerate, edit)
- [ ] Image support (for models that support it)
- [ ] Voice input integration

### Current UI State
- ✅ Provider selection working
- ✅ Model dropdown working
- ✅ Message bubbles styled correctly
- ✅ Auto-scroll implemented
- ✅ Loading indicator working
- ✅ Real API responses from all providers

## Testing

### Manual Testing Checklist
When testing new builds:
- [ ] Provider switching updates model list correctly
- [ ] Messages appear in correct order
- [ ] User messages vs assistant messages styled differently
- [ ] Loading indicator shows during "API calls"
- [ ] Auto-scroll works when new messages arrive
- [ ] Clear history removes all messages
- [ ] Input field disables during loading
- [ ] Provider/model info shows on assistant messages

### Future Automated Tests
- [ ] Unit tests for `ChatSession`
- [ ] UI tests for message flow
- [ ] Mock API response tests
- [ ] Error handling tests

## Development Workflow

### Making Changes

**From phone (via Claude Code)**:
1. Chat with Claude Code to make changes
2. Claude Code edits Swift files
3. Changes are automatically saved locally
4. When ready to deploy, use `/deploy` slash command
   - This commits changes and pushes to GitHub
   - Desktop watcher detects the push (~15 seconds)
   - Watcher automatically builds and uploads to TestFlight (~2-5 minutes)
   - Apple processes build (10-30 minutes)
5. Wait for TestFlight notification
6. Test on phone

**From computer**:
1. Edit Swift files in Xcode or any editor
2. Commit and push to GitHub
3. Watcher automatically deploys to TestFlight
4. Wait for TestFlight notification
5. Test on phone

**Manual deployment (if watcher isn't running)**:
1. Run `./deploy-to-testflight.sh` to deploy directly
2. This bypasses git and deploys current working directory
3. Wait for TestFlight build

**Important**:
- The `/deploy` command only pushes to GitHub - the desktop watcher handles the actual build
- Make sure the watcher is running: `./watch-and-deploy-testflight.sh`
- Changes are committed automatically with `/deploy`

### Project Structure
```
AIgent/
├── AIgent/
│   ├── AIgentApp.swift          # App entry point
│   ├── ContentView.swift        # Main chat UI
│   ├── Models.swift             # Data models
│   └── Assets.xcassets/
│       └── AppIcon.appiconset/  # App icons
├── fastlane/
│   ├── Fastfile                 # Deployment config
│   └── .env                     # API credentials (not in git)
├── .gitignore                   # Ignores build artifacts
├── watch-and-deploy-testflight.sh
├── README.md
├── DEPLOYMENT_APPROACH.md
├── DEPLOYMENT_SETUP.md
└── .claude/
    └── claude.md                # This file
```

## Common Tasks

### Adding a New Provider

1. Add to `LLMProvider` enum in `Models.swift`
2. Add icon name in `iconName` computed property
3. Add models in `models` computed property
4. Implement API integration in `ChatSession.sendMessage()`
5. Test provider switching and model selection
6. Update this documentation

### Modifying UI Layout

- Main layout is in `ContentView.swift`
- Message styling in `MessageBubble` struct
- Colors use system colors for dark mode support
- Spacing and padding follow iOS HIG

### Debugging Issues

**Message not sending**:
- Check `ChatSession.isLoading` state
- Verify `sendMessage()` is called
- Check for errors in Xcode console

**UI not updating**:
- Ensure `ChatSession` is `ObservableObject`
- Check `@Published` properties
- Verify `@StateObject` usage in `ContentView`

**Build fails**:
- Check Xcode build errors
- Verify all files in project
- Clean build folder (⌘⇧K)
- Check deployment logs in `deploy.log`

## Notes

### Current Limitations
- No conversation persistence (messages lost on app close)
- No streaming responses (full response at once)
- No API key validation on entry
- Single conversation at a time (no conversation switching)

### Design Decisions
- SwiftUI-only (no UIKit)
- Placeholder icons (blue background, can be replaced)
- Simple message format (text only for now)
- In-memory messages only (no database)

### Future Considerations
- Consider using a protocol for LLM providers to standardize API calls
- May need rate limiting UI for API quotas
- Consider adding message editing (regenerate with different params)
- Could add conversation branching/forking

---

**When working on this project, remember**:
1. This is a multi-LLM chat app - focus on provider flexibility
2. All API integrations are working - test thoroughly before deploying
3. Use `/deploy` command to push to TestFlight when ready
4. API keys are stored securely in Keychain
5. Follow the shared mobile app deployment workflow (see included file above)

## Key Files Added

- `APIService.swift` - Real API integrations for all providers
- `SettingsManager.swift` - Keychain-based API key storage
- `SettingsView.swift` - UI for managing API keys
- `deploy-to-testflight.sh` - Manual deployment script
- `.claude/commands/deploy.md` - `/deploy` slash command
