//
//  Models.swift
//  AIgent
//
//  Created by Joel Dehlin on 1/31/26.
//

import Foundation

// MARK: - LLM Provider

enum LLMProvider: String, CaseIterable, Identifiable {
    case openAI = "OpenAI"
    case anthropic = "Anthropic"
    case google = "Google"
    case meta = "Meta"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .openAI: return "brain.head.profile"
        case .anthropic: return "sparkles"
        case .google: return "g.circle"
        case .meta: return "m.circle"
        }
    }

    var models: [String] {
        switch self {
        case .openAI:
            return ["GPT-4", "GPT-4 Turbo", "GPT-3.5 Turbo"]
        case .anthropic:
            return ["Claude 3.5 Sonnet", "Claude 3 Opus", "Claude 3 Haiku"]
        case .google:
            return ["Gemini Pro", "Gemini Ultra"]
        case .meta:
            return ["Llama 3", "Llama 2"]
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

    init(content: String, isUser: Bool, provider: LLMProvider? = nil, model: String? = nil) {
        self.content = content
        self.isUser = isUser
        self.timestamp = Date()
        self.provider = provider
        self.model = model
    }
}

// MARK: - Chat Session

class ChatSession: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isLoading = false

    func sendMessage(_ content: String, provider: LLMProvider, model: String) {
        // Add user message
        let userMessage = Message(content: content, isUser: true)
        messages.append(userMessage)

        // Simulate API call (replace with actual API integration)
        isLoading = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            let response = "This is a placeholder response from \(provider.rawValue) (\(model)). Integrate actual API calls here."
            let assistantMessage = Message(
                content: response,
                isUser: false,
                provider: provider,
                model: model
            )
            self?.messages.append(assistantMessage)
            self?.isLoading = false
        }
    }

    func clearHistory() {
        messages.removeAll()
    }
}
