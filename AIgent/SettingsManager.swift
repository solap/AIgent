//
//  SettingsManager.swift
//  AIgent
//
//  Created by Joel Dehlin on 1/31/26.
//

import Foundation
import Security

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    private let service = "com.doogan.AIgent"

    private init() {}

    // MARK: - API Key Management

    func setAPIKey(_ key: String, for provider: LLMProvider) {
        let account = "\(provider.rawValue)-api-key"

        // Delete existing key first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new key
        guard let keyData = key.data(using: .utf8) else { return }

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        SecItemAdd(addQuery as CFDictionary, nil)
    }

    func getAPIKey(for provider: LLMProvider) -> String? {
        let account = "\(provider.rawValue)-api-key"

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }

        return key
    }

    func deleteAPIKey(for provider: LLMProvider) {
        let account = "\(provider.rawValue)-api-key"

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)
    }

    func clearAllKeys() {
        for provider in LLMProvider.allCases {
            deleteAPIKey(for: provider)
        }
    }

    // MARK: - Key Validation

    func hasAPIKey(for provider: LLMProvider) -> Bool {
        return getAPIKey(for: provider) != nil
    }

    // MARK: - System Prompt Management

    private let systemPromptsKey = "systemPrompts"

    func setSystemPrompt(_ prompt: String, for provider: LLMProvider) {
        var prompts = getSystemPrompts()
        prompts[provider.rawValue] = prompt.isEmpty ? nil : prompt
        saveSystemPrompts(prompts)
    }

    func getSystemPrompt(for provider: LLMProvider) -> String? {
        let prompts = getSystemPrompts()
        return prompts[provider.rawValue]
    }

    private func getSystemPrompts() -> [String: String] {
        guard let data = UserDefaults.standard.data(forKey: systemPromptsKey),
              let prompts = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return prompts
    }

    private func saveSystemPrompts(_ prompts: [String: String]) {
        if let data = try? JSONEncoder().encode(prompts) {
            UserDefaults.standard.set(data, forKey: systemPromptsKey)
        }
    }
}
