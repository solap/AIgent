//
//  ConversationListView.swift
//  AIgent
//
//  Created by Joel Dehlin on 1/31/26.
//

import SwiftUI

struct ConversationListView: View {
    @ObservedObject var storage: ConversationStorage
    @Binding var selectedConversation: Conversation?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(storage.conversations) { conversation in
                    ConversationRow(conversation: conversation)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedConversation = conversation
                            dismiss()
                        }
                }
                .onDelete(perform: deleteConversations)
            }
            .navigationTitle("Conversations")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        let newConversation = storage.createConversation()
                        selectedConversation = newConversation
                        dismiss()
                    } label: {
                        Label("New Chat", systemImage: "square.and.pencil")
                    }
                }
            }
            .overlay {
                if storage.conversations.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary)
                        Text("No conversations yet")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("Start a new chat to begin")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private func deleteConversations(at offsets: IndexSet) {
        for index in offsets {
            storage.deleteConversation(storage.conversations[index])
        }
    }
}

// MARK: - Conversation Row

struct ConversationRow: View {
    let conversation: Conversation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title and provider badges
            HStack {
                Text(conversation.title)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                // Show provider icons for models used in this conversation
                HStack(spacing: 4) {
                    ForEach(Array(conversation.usedProviders), id: \.self) { provider in
                        Image(systemName: provider.iconName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Last message preview
            if let lastMessage = conversation.messages.last {
                Text(lastMessage.content)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            // Timestamp
            Text(conversation.updatedAt, style: .relative)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}
