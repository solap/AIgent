//
//  Conversation.swift
//  AIgent
//
//  Created by Joel Dehlin on 1/31/26.
//

import Foundation

// MARK: - Provider Response (for multi-model responses)

struct ProviderResponse: Identifiable, Codable {
    let id: UUID
    let provider: LLMProvider
    let model: String
    let content: String
    let timestamp: Date

    init(provider: LLMProvider, model: String, content: String) {
        self.id = UUID()
        self.provider = provider
        self.model = model
        self.content = content
        self.timestamp = Date()
    }
}

// MARK: - Enhanced Message (supports multi-model responses)

struct ConversationMessage: Identifiable, Codable {
    let id: UUID
    let content: String
    let isUser: Bool
    let timestamp: Date

    // Single model response
    let provider: LLMProvider?
    let model: String?

    // Multi-model responses (when "Ask All" is used)
    let multiResponses: [ProviderResponse]?

    var isMultiModel: Bool {
        multiResponses != nil && !(multiResponses?.isEmpty ?? true)
    }

    // User message
    init(content: String, isUser: Bool) {
        self.id = UUID()
        self.content = content
        self.isUser = isUser
        self.timestamp = Date()
        self.provider = nil
        self.model = nil
        self.multiResponses = nil
    }

    // Single model response
    init(content: String, provider: LLMProvider, model: String) {
        self.id = UUID()
        self.content = content
        self.isUser = false
        self.timestamp = Date()
        self.provider = provider
        self.model = model
        self.multiResponses = nil
    }

    // Multi-model response
    init(userMessage: String, responses: [ProviderResponse]) {
        self.id = UUID()
        self.content = userMessage
        self.isUser = false
        self.timestamp = Date()
        self.provider = nil
        self.model = nil
        self.multiResponses = responses
    }
}

// MARK: - Conversation

struct Conversation: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var messages: [ConversationMessage]
    let createdAt: Date
    var updatedAt: Date

    static func == (lhs: Conversation, rhs: Conversation) -> Bool {
        lhs.id == rhs.id
    }

    // Derived: Which models were used in this conversation
    var usedProviders: Set<LLMProvider> {
        var providers = Set<LLMProvider>()
        for message in messages {
            if let provider = message.provider {
                providers.insert(provider)
            }
            if let multiResponses = message.multiResponses {
                for response in multiResponses {
                    providers.insert(response.provider)
                }
            }
        }
        return providers
    }

    init(title: String = "New Chat") {
        self.id = UUID()
        self.title = title
        self.messages = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // Auto-generate title from first user message
    mutating func updateTitle() {
        if title == "New Chat", let firstUserMessage = messages.first(where: { $0.isUser }) {
            let preview = firstUserMessage.content.prefix(50)
            title = preview.count < firstUserMessage.content.count ? "\(preview)..." : String(preview)
        }
    }

    mutating func addMessage(_ message: ConversationMessage) {
        messages.append(message)
        updatedAt = Date()
        updateTitle()
    }
}
