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
            return ["Claude 3.5 Sonnet", "Claude 3 Opus", "Claude 3 Haiku"]
        case .openAI:
            return ["GPT-4o", "GPT-4 Turbo", "GPT-4", "GPT-3.5 Turbo"]
        case .google:
            return ["Gemini 2.0 Flash", "Gemini 1.5 Pro", "Gemini 1.5 Flash"]
        case .grok:
            return ["grok-beta", "grok-2-1212", "grok-2-vision-1212"]
        }
    }

    var apiModelId: String {
        // Returns the actual API model identifier
        switch self {
        case .anthropic:
            return models.first ?? "claude-3-5-sonnet-20250122"
        case .openAI:
            return models.first ?? "gpt-4o"
        case .google:
            return models.first ?? "gemini-2.0-flash-exp"
        case .grok:
            return models.first ?? "grok-2-latest"
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

    // Multi-model support
    let isMultiModel: Bool
    let multiResponses: [ProviderResponse]?

    init(content: String, isUser: Bool, provider: LLMProvider? = nil, model: String? = nil) {
        self.content = content
        self.isUser = isUser
        self.timestamp = Date()
        self.provider = provider
        self.model = model
        self.isMultiModel = false
        self.multiResponses = nil
    }

    init(content: String, isUser: Bool, isMultiModel: Bool, multiResponses: [ProviderResponse]?) {
        self.content = content
        self.isUser = isUser
        self.timestamp = Date()
        self.provider = nil
        self.model = nil
        self.isMultiModel = isMultiModel
        self.multiResponses = multiResponses
    }
}

// MARK: - Chat Session

class ChatSession: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func sendMessage(_ content: String, provider: LLMProvider, model: String) {
        // Add user message
        let userMessage = Message(content: content, isUser: true)
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
                    conversationHistory: history
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

    func sendMessageToAllModels(_ content: String) {
        // Add user message
        let userMessage = Message(content: content, isUser: true)
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
                conversationHistory: history
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
