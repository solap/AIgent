//
//  SettingsView.swift
//  AIgent
//
//  Created by Joel Dehlin on 1/31/26.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var settingsManager = SettingsManager.shared

    @State private var openAIKey: String = ""
    @State private var anthropicKey: String = ""
    @State private var googleKey: String = ""
    @State private var grokKey: String = ""
    @State private var tavilyKey: String = ""

    @State private var openAISystemPrompt: String = ""
    @State private var anthropicSystemPrompt: String = ""
    @State private var googleSystemPrompt: String = ""
    @State private var grokSystemPrompt: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Enter your API keys for each provider. Keys are stored securely in Keychain.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section(header: Label("OpenAI", systemImage: "brain.head.profile")) {
                    SecureField("API Key", text: $openAIKey)
                        .textContentType(.password)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()

                    TextField("System Prompt (optional)", text: $openAISystemPrompt, axis: .vertical)
                        .lineLimit(3...6)
                        .font(.caption)
                }

                Section(header: Label("Anthropic", systemImage: "sparkles")) {
                    SecureField("API Key", text: $anthropicKey)
                        .textContentType(.password)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()

                    TextField("System Prompt (optional)", text: $anthropicSystemPrompt, axis: .vertical)
                        .lineLimit(3...6)
                        .font(.caption)
                }

                Section(header: Label("Google", systemImage: "g.circle")) {
                    SecureField("API Key", text: $googleKey)
                        .textContentType(.password)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()

                    TextField("System Prompt (optional)", text: $googleSystemPrompt, axis: .vertical)
                        .lineLimit(3...6)
                        .font(.caption)
                }

                Section(header: Label("Grok", systemImage: "bolt.circle")) {
                    SecureField("API Key", text: $grokKey)
                        .textContentType(.password)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()

                    TextField("System Prompt (optional)", text: $grokSystemPrompt, axis: .vertical)
                        .lineLimit(3...6)
                        .font(.caption)
                }

                Section(header: Label("Web Search (Tavily)", systemImage: "magnifyingglass")) {
                    SecureField("Tavily API Key", text: $tavilyKey)
                        .textContentType(.password)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()

                    Text("Enable web search to give all models access to current information. Get a key at tavily.com")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section {
                    Button("Clear All Keys") {
                        settingsManager.clearAllKeys()
                        loadKeys()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveKeys()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                loadKeys()
            }
        }
    }

    private func loadKeys() {
        openAIKey = settingsManager.getAPIKey(for: .openAI) ?? ""
        anthropicKey = settingsManager.getAPIKey(for: .anthropic) ?? ""
        googleKey = settingsManager.getAPIKey(for: .google) ?? ""
        grokKey = settingsManager.getAPIKey(for: .grok) ?? ""
        tavilyKey = settingsManager.getTavilyAPIKey() ?? ""

        openAISystemPrompt = settingsManager.getSystemPrompt(for: .openAI) ?? ""
        anthropicSystemPrompt = settingsManager.getSystemPrompt(for: .anthropic) ?? ""
        googleSystemPrompt = settingsManager.getSystemPrompt(for: .google) ?? ""
        grokSystemPrompt = settingsManager.getSystemPrompt(for: .grok) ?? ""
    }

    private func saveKeys() {
        if !openAIKey.isEmpty {
            settingsManager.setAPIKey(openAIKey, for: .openAI)
        }
        if !anthropicKey.isEmpty {
            settingsManager.setAPIKey(anthropicKey, for: .anthropic)
        }
        if !googleKey.isEmpty {
            settingsManager.setAPIKey(googleKey, for: .google)
        }
        if !grokKey.isEmpty {
            settingsManager.setAPIKey(grokKey, for: .grok)
        }
        settingsManager.setTavilyAPIKey(tavilyKey)

        settingsManager.setSystemPrompt(openAISystemPrompt, for: .openAI)
        settingsManager.setSystemPrompt(anthropicSystemPrompt, for: .anthropic)
        settingsManager.setSystemPrompt(googleSystemPrompt, for: .google)
        settingsManager.setSystemPrompt(grokSystemPrompt, for: .grok)
    }
}

#Preview {
    SettingsView()
}
