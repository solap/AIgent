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
                }

                Section(header: Label("Anthropic", systemImage: "sparkles")) {
                    SecureField("API Key", text: $anthropicKey)
                        .textContentType(.password)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }

                Section(header: Label("Google", systemImage: "g.circle")) {
                    SecureField("API Key", text: $googleKey)
                        .textContentType(.password)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }

                Section(header: Label("Grok", systemImage: "bolt.circle")) {
                    SecureField("API Key", text: $grokKey)
                        .textContentType(.password)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
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
    }
}

#Preview {
    SettingsView()
}
