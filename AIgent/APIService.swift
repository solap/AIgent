//
//  APIService.swift
//  AIgent
//
//  Created by Joel Dehlin on 1/31/26.
//

import Foundation

class APIService {
    static let shared = APIService()

    private init() {}

    // MARK: - Main API Call

    func sendMessage(_ message: String, provider: LLMProvider, model: String, conversationHistory: [Message]) async throws -> String {
        guard let apiKey = SettingsManager.shared.getAPIKey(for: provider) else {
            throw APIError.missingAPIKey
        }

        switch provider {
        case .anthropic:
            return try await sendAnthropicMessage(message, model: model, apiKey: apiKey, history: conversationHistory)
        case .openAI:
            return try await sendOpenAIMessage(message, model: model, apiKey: apiKey, history: conversationHistory)
        case .google:
            return try await sendGoogleMessage(message, model: model, apiKey: apiKey, history: conversationHistory)
        case .grok:
            return try await sendGrokMessage(message, model: model, apiKey: apiKey, history: conversationHistory)
        }
    }

    // MARK: - Anthropic API

    private func sendAnthropicMessage(_ message: String, model: String, apiKey: String, history: [Message]) async throws -> String {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        // Convert model name to API model ID
        let modelId = getAnthropicModelId(model)

        // Build conversation history
        var messages: [[String: Any]] = []
        for msg in history where msg.isUser {
            messages.append([
                "role": "user",
                "content": msg.content
            ])

            // Find corresponding assistant response
            if let index = history.firstIndex(where: { $0.id == msg.id }),
               index + 1 < history.count,
               !history[index + 1].isUser {
                messages.append([
                    "role": "assistant",
                    "content": history[index + 1].content
                ])
            }
        }

        // Add current message
        messages.append([
            "role": "user",
            "content": message
        ])

        let body: [String: Any] = [
            "model": modelId,
            "max_tokens": 4096,
            "messages": messages
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let content = json?["content"] as? [[String: Any]],
              let text = content.first?["text"] as? String else {
            throw APIError.invalidResponse
        }

        return text
    }

    // MARK: - OpenAI API

    private func sendOpenAIMessage(_ message: String, model: String, apiKey: String, history: [Message]) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        // Convert model name to API model ID
        let modelId = getOpenAIModelId(model)

        // Build conversation history
        var messages: [[String: Any]] = []

        for msg in history {
            messages.append([
                "role": msg.isUser ? "user" : "assistant",
                "content": msg.content
            ])
        }

        // Add current message
        messages.append([
            "role": "user",
            "content": message
        ])

        let body: [String: Any] = [
            "model": modelId,
            "messages": messages
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let choices = json?["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let messageObj = firstChoice["message"] as? [String: Any],
              let content = messageObj["content"] as? String else {
            throw APIError.invalidResponse
        }

        return content
    }

    // MARK: - Google Gemini API

    private func sendGoogleMessage(_ message: String, model: String, apiKey: String, history: [Message]) async throws -> String {
        // Convert model name to API model ID
        let modelId = getGoogleModelId(model)

        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(modelId):generateContent?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        // Build conversation history
        var contents: [[String: Any]] = []

        for msg in history {
            contents.append([
                "role": msg.isUser ? "user" : "model",
                "parts": [["text": msg.content]]
            ])
        }

        // Add current message
        contents.append([
            "role": "user",
            "parts": [["text": message]]
        ])

        let body: [String: Any] = [
            "contents": contents
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let candidates = json?["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            throw APIError.invalidResponse
        }

        return text
    }

    // MARK: - Grok API (xAI)

    private func sendGrokMessage(_ message: String, model: String, apiKey: String, history: [Message]) async throws -> String {
        let url = URL(string: "https://api.x.ai/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        // Convert model name to API model ID
        let modelId = getGrokModelId(model)

        // Build conversation history
        var messages: [[String: Any]] = []

        for msg in history {
            messages.append([
                "role": msg.isUser ? "user" : "assistant",
                "content": msg.content
            ])
        }

        // Add current message
        messages.append([
            "role": "user",
            "content": message
        ])

        let body: [String: Any] = [
            "model": modelId,
            "messages": messages
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let choices = json?["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let messageObj = firstChoice["message"] as? [String: Any],
              let content = messageObj["content"] as? String else {
            throw APIError.invalidResponse
        }

        return content
    }

    // MARK: - Model ID Helpers

    private func getAnthropicModelId(_ modelName: String) -> String {
        switch modelName {
        case "Claude 3.5 Sonnet":
            return "claude-3-5-sonnet-20250122"
        case "Claude 3 Opus":
            return "claude-3-opus-20240229"
        case "Claude 3 Haiku":
            return "claude-3-haiku-20240307"
        default:
            return "claude-3-5-sonnet-20250122"
        }
    }

    private func getOpenAIModelId(_ modelName: String) -> String {
        switch modelName {
        case "GPT-4o":
            return "gpt-4o"
        case "GPT-4 Turbo":
            return "gpt-4-turbo"
        case "GPT-4":
            return "gpt-4"
        case "GPT-3.5 Turbo":
            return "gpt-3.5-turbo"
        default:
            return "gpt-4o"
        }
    }

    private func getGoogleModelId(_ modelName: String) -> String {
        switch modelName {
        case "Gemini 2.0 Flash":
            return "gemini-2.0-flash-exp"
        case "Gemini 1.5 Pro":
            return "gemini-1.5-pro"
        case "Gemini 1.5 Flash":
            return "gemini-1.5-flash"
        default:
            return "gemini-2.0-flash-exp"
        }
    }

    private func getGrokModelId(_ modelName: String) -> String {
        switch modelName {
        case "grok-2-latest":
            return "grok-2-latest"
        case "grok-beta":
            return "grok-beta"
        default:
            return "grok-2-latest"
        }
    }
}

// MARK: - API Error

enum APIError: Error, LocalizedError {
    case missingAPIKey
    case invalidResponse
    case httpError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API key not found. Please add your API key in Settings."
        case .invalidResponse:
            return "Invalid response from API."
        case .httpError(let statusCode, let message):
            return "API Error (\(statusCode)): \(message)"
        }
    }
}
