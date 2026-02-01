# Settings & API Key Management

## Overview

AIgent includes a secure settings page for managing API keys for all LLM providers.

## Files

### `AIgent/SettingsView.swift`
Settings page UI for API key management.

**Features**:
- Secure input fields (`SecureField`) for each LLM provider
- Modal presentation from gear icon in main navigation bar
- Cancel/Save buttons for managing changes
- Clear all keys option
- Instructions for users about Keychain storage

**Providers**:
- OpenAI (brain.head.profile icon)
- Anthropic (sparkles icon)
- Google (g.circle icon)
- Meta (m.circle icon)

**Usage in ContentView**:
```swift
@State private var showingSettings = false

// In toolbar
ToolbarItem(placement: .navigationBarLeading) {
    Button {
        showingSettings = true
    } label: {
        Image(systemName: "gear")
    }
}

// As sheet
.sheet(isPresented: $showingSettings) {
    SettingsView()
}
```

### `AIgent/SettingsManager.swift`
Singleton manager for secure API key storage using iOS Keychain.

**Key Methods**:
```swift
// Get the shared instance
SettingsManager.shared

// Store an API key
func setAPIKey(_ key: String, for provider: LLMProvider)

// Retrieve an API key
func getAPIKey(for provider: LLMProvider) -> String?

// Delete a specific API key
func deleteAPIKey(for provider: LLMProvider)

// Delete all API keys
func clearAllKeys()

// Check if key exists
func hasAPIKey(for provider: LLMProvider) -> Bool
```

**Security Details**:
- Uses iOS Keychain (`kSecClassGenericPassword`)
- Service identifier: `com.doogan.AIgent`
- Account format: `{ProviderName}-api-key` (e.g., "OpenAI-api-key")
- Accessibility: `kSecAttrAccessibleWhenUnlocked` (keys only accessible when device is unlocked)
- Keys persist across app launches and updates
- Keys are NOT synced via iCloud (device-local only)

**Example Usage**:
```swift
let manager = SettingsManager.shared

// Save a key
manager.setAPIKey("sk-abc123...", for: .openAI)

// Retrieve a key
if let apiKey = manager.getAPIKey(for: .anthropic) {
    // Use the key for API calls
}

// Check if key exists
if manager.hasAPIKey(for: .google) {
    // Provider is configured
}

// Clear all keys (e.g., on logout)
manager.clearAllKeys()
```

## Integration with API Calls

When implementing actual API integrations in `ChatSession.sendMessage()`:

```swift
func sendMessage(_ content: String, provider: LLMProvider, model: String) {
    // Get API key from secure storage
    guard let apiKey = SettingsManager.shared.getAPIKey(for: provider) else {
        // Show error: "Please add {provider} API key in settings"
        return
    }

    // Use apiKey to make actual API call
    switch provider {
    case .openAI:
        // Initialize OpenAI client with apiKey
    case .anthropic:
        // Initialize Anthropic client with apiKey
    // ... etc
    }
}
```

## TODO

- [x] Settings UI complete
- [x] Keychain storage implemented
- [ ] Add API key validation on save
- [ ] Add visual indicator in main UI when keys are missing
- [ ] Implement actual API calls using stored keys
- [ ] Add key testing feature (validate key works before saving)
