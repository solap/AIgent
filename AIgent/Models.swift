//
//  Models.swift
//  AIgent
//
//  Created by Joel Dehlin on 1/31/26.
//

import Foundation

// MARK: - LLM Provider

enum LLMProvider: String, CaseIterable, Identifiable, Codable {
    case anthropic = "Anthropic"
    case openAI = "OpenAI"
    case google = "Google"
    case grok = "Grok"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .anthropic: return "sparkles"
        case .openAI: return "brain.head.profile"
        case .google: return "g.circle"
        case .grok: return "bolt.circle"
        }
    }

    var models: [String] {
        switch self {
        case .anthropic:
            return ["Claude Opus 4.6", "Claude Sonnet 4.5", "Claude Opus 4.1"]
        case .openAI:
            return ["GPT-4.1", "GPT-4.1 Mini", "GPT-4o", "GPT-4o Mini"]
        case .google:
            return ["Gemini 2.5 Flash", "Gemini 2.5 Pro", "Gemini 3 Flash"]
        case .grok:
            return ["Grok 4.1 Fast", "Grok 4", "Grok 3"]
        }
    }

    var apiModelId: String {
        // Returns the actual API model identifier
        switch self {
        case .anthropic:
            return models.first ?? "claude-opus-4-6"
        case .openAI:
            return models.first ?? "gpt-4.1"
        case .google:
            return models.first ?? "gemini-2.5-flash"
        case .grok:
            return models.first ?? "grok-4-1-fast"
        }
    }
}

// MARK: - Message

struct Message: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
    let provider: LLMProvider?
    let model: String?

    // Image support
    let imageData: Data?

    // Multi-model support
    let isMultiModel: Bool
    let multiResponses: [ProviderResponse]?

    init(content: String, isUser: Bool, provider: LLMProvider? = nil, model: String? = nil, imageData: Data? = nil) {
        self.content = content
        self.isUser = isUser
        self.timestamp = Date()
        self.provider = provider
        self.model = model
        self.imageData = imageData
        self.isMultiModel = false
        self.multiResponses = nil
    }

    init(content: String, isUser: Bool, isMultiModel: Bool, multiResponses: [ProviderResponse]?) {
        self.content = content
        self.isUser = isUser
        self.timestamp = Date()
        self.provider = nil
        self.model = nil
        self.imageData = nil
        self.isMultiModel = isMultiModel
        self.multiResponses = multiResponses
    }
}

// MARK: - Chat Session

class ChatSession: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func sendMessage(_ content: String, provider: LLMProvider, model: String, imageData: Data? = nil) {
        // Add user message
        let userMessage = Message(content: content, isUser: true, imageData: imageData)
        messages.append(userMessage)

        // Clear any previous errors
        errorMessage = nil
        isLoading = true

        Task { @MainActor in
            do {
                // Get conversation history (excluding the message we just added)
                let history = Array(messages.dropLast())

                // Call the API
                let response = try await APIService.shared.sendMessage(
                    content,
                    provider: provider,
                    model: model,
                    conversationHistory: history,
                    imageData: imageData
                )

                // Add assistant response
                let assistantMessage = Message(
                    content: response,
                    isUser: false,
                    provider: provider,
                    model: model
                )
                messages.append(assistantMessage)
                isLoading = false

            } catch {
                // Handle error
                errorMessage = error.localizedDescription
                let errorResponseMessage = Message(
                    content: "Error: \(error.localizedDescription)",
                    isUser: false,
                    provider: provider,
                    model: model
                )
                messages.append(errorResponseMessage)
                isLoading = false
            }
        }
    }

    func clearHistory() {
        messages.removeAll()
        errorMessage = nil
    }

    func sendMessageToAllModels(_ content: String, imageData: Data? = nil) {
        // Add user message
        let userMessage = Message(content: content, isUser: true, imageData: imageData)
        messages.append(userMessage)

        // Clear any previous errors
        errorMessage = nil
        isLoading = true

        Task { @MainActor in
            // Get conversation history (excluding the message we just added)
            let history = Array(messages.dropLast())

            // Call the API for all providers
            let responses = await APIService.shared.sendMessageToAll(
                content,
                conversationHistory: history,
                imageData: imageData
            )

            // Add multi-model response message
            let multiMessage = Message(
                content: "\(responses.count) models responded",
                isUser: false,
                isMultiModel: true,
                multiResponses: responses
            )
            messages.append(multiMessage)
            isLoading = false
        }
    }
}
