//
//  ContentView.swift
//  AIgent
//
//  Created by Joel Dehlin on 1/31/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var chatSession = ChatSession()
    @State private var inputText = ""
    @State private var selectedProvider: LLMProvider = .anthropic
    @State private var selectedModel = "Claude 3.5 Sonnet"
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Model Selector
                modelSelector

                Divider()

                // Messages List
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(chatSession.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
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
            .navigationTitle("AIgent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        chatSession.clearHistory()
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }

    // MARK: - Model Selector

    private var modelSelector: some View {
        VStack(spacing: 8) {
            // Provider Picker
            Picker("Provider", selection: $selectedProvider) {
                ForEach(LLMProvider.allCases) { provider in
                    HStack {
                        Image(systemName: provider.iconName)
                        Text(provider.rawValue)
                    }
                    .tag(provider)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            // Model Picker
            Picker("Model", selection: $selectedModel) {
                ForEach(selectedProvider.models, id: \.self) { model in
                    Text(model).tag(model)
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(uiColor: .systemGroupedBackground))
        .onChange(of: selectedProvider) { _, newProvider in
            selectedModel = newProvider.models.first ?? ""
        }
    }

    // MARK: - Input Area

    private var inputArea: some View {
        HStack(spacing: 12) {
            TextField("Message", text: $inputText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...5)

            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(inputText.isEmpty ? .gray : .blue)
            }
            .disabled(inputText.isEmpty || chatSession.isLoading)
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
    }

    private func sendMessage() {
        guard !inputText.isEmpty else { return }

        chatSession.sendMessage(inputText, provider: selectedProvider, model: selectedModel)
        inputText = ""
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: Message

    var body: some View {
        HStack {
            if message.isUser { Spacer() }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
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

#Preview {
    ContentView()
}
