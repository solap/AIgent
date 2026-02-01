//
//  ConversationStorage.swift
//  AIgent
//
//  Created by Joel Dehlin on 1/31/26.
//

import Foundation

class ConversationStorage: ObservableObject {
    static let shared = ConversationStorage()

    @Published var conversations: [Conversation] = []

    private let fileURL: URL

    private init() {
        // Get documents directory
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        fileURL = documentsDirectory.appendingPathComponent("conversations.json")

        loadConversations()
    }

    // MARK: - Persistence

    private func loadConversations() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            conversations = []
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            conversations = try JSONDecoder().decode([Conversation].self, from: data)
            // Sort by most recent first
            conversations.sort { $0.updatedAt > $1.updatedAt }
        } catch {
            print("Failed to load conversations: \(error)")
            conversations = []
        }
    }

    func saveConversations() {
        do {
            let data = try JSONEncoder().encode(conversations)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save conversations: \(error)")
        }
    }

    // MARK: - CRUD Operations

    func createConversation() -> Conversation {
        let conversation = Conversation()
        conversations.insert(conversation, at: 0)
        saveConversations()
        return conversation
    }

    func updateConversation(_ conversation: Conversation) {
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[index] = conversation
            // Move to top (most recent)
            let updated = conversations.remove(at: index)
            conversations.insert(updated, at: 0)
            saveConversations()
        }
    }

    func deleteConversation(_ conversation: Conversation) {
        conversations.removeAll { $0.id == conversation.id }
        saveConversations()
    }

    func getConversation(id: UUID) -> Conversation? {
        conversations.first { $0.id == id }
    }
}
