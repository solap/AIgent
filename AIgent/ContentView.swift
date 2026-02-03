//
//  ContentView.swift
//  AIgent
//
//  Multi-LLM Chat Interface
//  Created by Joel Dehlin on 1/31/26.
//

import SwiftUI
import PhotosUI

struct ContentView: View {
    @StateObject private var chatSession = ChatSession()
    @StateObject private var storage = ConversationStorage.shared

    @State private var inputText = ""
    @State private var selectedProvider: LLMProvider = .anthropic
    @State private var selectedModel = "Claude Sonnet 4.5"
    @State private var showingSettings = false
    @State private var showingConversationList = false
    @State private var currentConversation: Conversation?
    @State private var selectedMultiResponse: ProviderResponseWrapper?
    @FocusState private var isInputFocused: Bool

    // Image picker state
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImageData: Data?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Model Selector (always visible)
                modelSelector
                Divider()

                // Messages List
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(chatSession.messages) { message in
                                if message.isMultiModel, let responses = message.multiResponses {
                                    // Multi-model response bubble
                                    MultiModelMessageBubble(
                                        message: message,
                                        responses: responses
                                    )
                                    .onTapGesture {
                                        selectedMultiResponse = ProviderResponseWrapper(responses: responses)
                                    }
                                    .id(message.id)
                                } else {
                                    // Regular message bubble
                                    MessageBubble(message: message)
                                        .id(message.id)
                                }
                            }

                            if chatSession.isLoading {
                                LoadingIndicator()
                            }
                        }
                        .padding()
                    }
                    .onChange(of: chatSession.messages.count) { _, _ in
                        if let lastMessage = chatSession.messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }

                Divider()

                // Input Area
                inputArea
            }
            .navigationTitle(currentConversation?.title ?? "New Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button {
                            showingConversationList = true
                        } label: {
                            Label("All Conversations", systemImage: "list.bullet")
                        }

                        Button {
                            showingSettings = true
                        } label: {
                            Label("Settings", systemImage: "gear")
                        }

                        Divider()

                        Button {
                            copyAllMessages()
                        } label: {
                            Label("Copy All Messages", systemImage: "doc.on.doc")
                        }
                        .disabled(chatSession.messages.isEmpty)
                    } label: {
                        Image(systemName: "line.3.horizontal")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            copyAllMessages()
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .disabled(chatSession.messages.isEmpty)

                        Button {
                            startNewChat()
                        } label: {
                            Image(systemName: "square.and.pencil")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingConversationList) {
                ConversationListView(
                    storage: storage,
                    selectedConversation: $currentConversation
                )
            }
            .sheet(item: $selectedMultiResponse) { wrapper in
                MultiModelResponseView(responses: wrapper.responses)
            }
            .onAppear {
                if currentConversation == nil {
                    loadOrCreateConversation()
                }
            }
        }
    }

    // MARK: - Model Selector

    private var modelSelector: some View {
        HStack(spacing: 8) {
            // Provider + Model combined picker
            Menu {
                ForEach(LLMProvider.allCases) { provider in
                    Menu {
                        ForEach(provider.models, id: \.self) { model in
                            Button {
                                selectedProvider = provider
                                selectedModel = model
                            } label: {
                                if selectedProvider == provider && selectedModel == model {
                                    Label(model, systemImage: "checkmark")
                                } else {
                                    Text(model)
                                }
                            }
                        }
                    } label: {
                        Label(provider.rawValue, systemImage: provider.iconName)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: selectedProvider.iconName)
                        .font(.caption)
                    Text(selectedModel)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .font(.caption)
                .foregroundColor(.primary)
            }

            Spacer()

            // Ask All button
            Button {
                sendToAllModels()
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: "sparkles.rectangle.stack")
                    Text("Ask All")
                }
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(6)
            }
            .disabled(!canSend || chatSession.isLoading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(uiColor: .systemGroupedBackground))
        .onChange(of: currentConversation) { _, _ in
            loadConversationMessages()
        }
    }

    // MARK: - Input Area

    private var inputArea: some View {
        VStack(spacing: 8) {
            // Image preview
            if let imageData = selectedImageData, let uiImage = UIImage(data: imageData) {
                HStack {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 60)
                        .cornerRadius(8)

                    Button {
                        selectedImageData = nil
                        selectedPhotoItem = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }

                    Spacer()
                }
                .padding(.horizontal)
            }

            HStack(alignment: .bottom, spacing: 8) {
                // Image picker button
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Image(systemName: "photo")
                        .font(.system(size: 22))
                        .foregroundStyle(.blue)
                }
                .onChange(of: selectedPhotoItem) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                            selectedImageData = data
                        }
                    }
                }

                // Paste button for clipboard images
                Button {
                    pasteImageFromClipboard()
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 20))
                        .foregroundStyle(.blue)
                }

                TextField("Message", text: $inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...10)
                    .focused($isInputFocused)

                // Send button
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(canSend ? .blue : .gray)
                }
                .disabled(!canSend || chatSession.isLoading)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(uiColor: .systemBackground))
    }

    private var canSend: Bool {
        !inputText.isEmpty || selectedImageData != nil
    }

    // MARK: - Actions

    private func sendMessage() {
        guard !inputText.isEmpty || selectedImageData != nil else { return }

        let messageText = inputText.isEmpty ? "What's in this image?" : inputText
        let imageData = selectedImageData

        inputText = ""
        selectedImageData = nil
        selectedPhotoItem = nil

        chatSession.sendMessage(messageText, provider: selectedProvider, model: selectedModel, imageData: imageData)

        // Save to conversation
        saveCurrentConversation()
    }

    private func sendToAllModels() {
        guard !inputText.isEmpty || selectedImageData != nil else { return }

        let messageText = inputText.isEmpty ? "What's in this image?" : inputText
        let imageData = selectedImageData

        inputText = ""
        selectedImageData = nil
        selectedPhotoItem = nil

        chatSession.sendMessageToAllModels(messageText, imageData: imageData)

        // Save to conversation
        saveCurrentConversation()
    }

    private func startNewChat() {
        // Save current conversation if it has messages
        if let current = currentConversation, !current.messages.isEmpty {
            saveCurrentConversation()
        }

        // Create new conversation
        let newConversation = storage.createConversation()
        currentConversation = newConversation
        chatSession.clearHistory()
    }

    private func loadOrCreateConversation() {
        if storage.conversations.isEmpty {
            currentConversation = storage.createConversation()
        } else {
            currentConversation = storage.conversations.first
            loadConversationMessages()
        }
    }

    private func loadConversationMessages() {
        guard let conversation = currentConversation else { return }

        // Convert ConversationMessages back to old Message format for display
        chatSession.messages = conversation.messages.map { msg in
            if msg.isUser {
                return Message(content: msg.content, isUser: true)
            } else if let responses = msg.multiResponses {
                // For multi-model, create a placeholder message
                return Message(content: msg.content, isUser: false, isMultiModel: true, multiResponses: responses)
            } else if let provider = msg.provider, let model = msg.model {
                return Message(content: msg.content, isUser: false, provider: provider, model: model)
            } else {
                return Message(content: msg.content, isUser: false)
            }
        }
    }

    private func saveCurrentConversation() {
        guard var conversation = currentConversation else { return }

        // Convert current chat messages to ConversationMessage format
        conversation.messages = chatSession.messages.map { msg in
            if msg.isUser {
                return ConversationMessage(content: msg.content, isUser: true)
            } else if let responses = msg.multiResponses {
                return ConversationMessage(userMessage: msg.content, responses: responses)
            } else if let provider = msg.provider, let model = msg.model {
                return ConversationMessage(content: msg.content, provider: provider, model: model)
            } else {
                return ConversationMessage(content: msg.content, isUser: false)
            }
        }

        storage.updateConversation(conversation)
        currentConversation = conversation
    }

    private func pasteImageFromClipboard() {
        if UIPasteboard.general.hasImages, let image = UIPasteboard.general.image {
            selectedImageData = image.jpegData(compressionQuality: 0.8)
        }
    }

    private func copyAllMessages() {
        let allText = chatSession.messages.map { message in
            let role = message.isUser ? "You" : (message.provider?.rawValue ?? "Assistant")
            let modelInfo = message.model.map { " (\($0))" } ?? ""
            return "\(role)\(modelInfo):\n\(message.content)\n"
        }.joined(separator: "\n")

        // Clear pasteboard first, then set string to avoid rich text issues
        UIPasteboard.general.items = []
        UIPasteboard.general.setValue(allText, forPasteboardType: "public.plain-text")
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: Message

    var body: some View {
        HStack {
            if message.isUser { Spacer() }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
                    // Show image if present
                    if let imageData = message.imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 200)
                            .cornerRadius(12)
                    }

                    Text(message.content)
                        .textSelection(.enabled)
                }
                .padding(12)
                .background(message.isUser ? Color.blue : Color(uiColor: .systemGray5))
                .foregroundColor(message.isUser ? .white : .primary)
                .cornerRadius(16)

                if !message.isUser, let provider = message.provider, let model = message.model {
                    HStack(spacing: 4) {
                        Image(systemName: provider.iconName)
                        Text("\(provider.rawValue) · \(model)")
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
            }

            if !message.isUser { Spacer() }
        }
    }
}

// MARK: - Multi-Model Message Bubble

struct MultiModelMessageBubble: View {
    let message: Message
    let responses: [ProviderResponse]

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "sparkles.rectangle.stack")
                    Text("\(responses.count) model responses")
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color.purple.opacity(0.1))
                .foregroundColor(.purple)
                .cornerRadius(16)

                // Show provider icons
                HStack(spacing: 4) {
                    ForEach(responses) { response in
                        Image(systemName: response.provider.iconName)
                            .font(.caption)
                    }
                    Text("Tap to view all")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Loading Indicator

struct LoadingIndicator: View {
    var body: some View {
        HStack {
            ProgressView()
                .padding(12)
                .background(Color(uiColor: .systemGray5))
                .cornerRadius(16)

            Spacer()
        }
    }
}

// Wrapper to make [ProviderResponse] Identifiable for sheet presentation
struct ProviderResponseWrapper: Identifiable {
    let id = UUID()
    let responses: [ProviderResponse]
}

#Preview {
    ContentView()
}
