# AIgent - Multi-LLM Chat Interface

<!-- Include shared mobile app deployment instructions -->
@/Users/joeldehlin/projects/.claude/mobile-app-base.md

---

## Project Overview

AIgent is a unified iOS chat interface that allows users to interact with multiple Large Language Model providers through a single app.

### Purpose
- Chat with AI models from different providers (OpenAI, Anthropic, Google, Meta)
- Compare responses across different models
- Switch providers and models easily during conversation
- Clean, native iOS experience with SwiftUI

### Current Status
🚧 **In Development** - UI and settings complete, API integrations are placeholders

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

### Supported Models

#### OpenAI
- GPT-4
- GPT-4 Turbo
- GPT-3.5 Turbo

#### Anthropic
- Claude 3.5 Sonnet
- Claude 3 Opus
- Claude 3 Haiku

#### Google
- Gemini Pro
- Gemini Ultra

#### Meta
- Llama 3
- Llama 2

## API Integration TODOs

### High Priority
Each provider needs actual API implementation in `ChatSession.sendMessage()`:

**OpenAI Integration**:
- [ ] Add OpenAI SDK dependency
- [ ] Implement API key management
- [ ] Replace placeholder with real API calls
- [ ] Handle streaming responses
- [ ] Error handling for rate limits, invalid keys, etc.

**Anthropic Integration**:
- [ ] Add Anthropic SDK dependency
- [ ] Implement API key management
- [ ] Replace placeholder with real API calls
- [ ] Handle streaming responses
- [ ] Error handling

**Google Integration**:
- [ ] Add Google Generative AI SDK
- [ ] Implement API key management
- [ ] Replace placeholder with real API calls
- [ ] Handle streaming responses
- [ ] Error handling

**Meta Integration**:
- [ ] Determine API access method (likely via Replicate or Together AI)
- [ ] Add appropriate SDK
- [ ] Implement API key management
- [ ] Replace placeholder with real API calls
- [ ] Error handling

### API Key Storage
Need to implement secure storage:
- [ ] Use Keychain for API key storage
- [ ] Settings screen for API key entry
- [ ] Validation of API keys on save
- [ ] Per-provider enable/disable based on key availability

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
- ⚠️ Placeholder responses only

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

**From phone**:
1. Use Claude Code mobile or Working Copy
2. Edit Swift files
3. Commit with descriptive message
4. Push to GitHub
5. Watcher auto-deploys to TestFlight (~15 min total)
6. Test on phone

**Important**: Always test in Xcode Simulator first if possible, to catch build errors before pushing.

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
- No actual API integrations (placeholder responses only)
- No conversation persistence
- No streaming responses
- No error handling for API failures
- No API key management UI

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
2. UI is complete, focus on API integrations next
3. Test provider switching thoroughly
4. Keep placeholder responses until real APIs are implemented
5. Follow the shared mobile app deployment workflow (see included file above)
