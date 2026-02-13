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

    // MARK: - Image Helper

    private func detectImageMimeType(_ data: Data) -> String {
        // Check magic bytes to detect image type
        var bytes = [UInt8](repeating: 0, count: 8)
        data.copyBytes(to: &bytes, count: min(8, data.count))

        // PNG: 89 50 4E 47
        if bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 {
            return "image/png"
        }
        // JPEG: FF D8 FF
        if bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF {
            return "image/jpeg"
        }
        // GIF: 47 49 46 38
        if bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38 {
            return "image/gif"
        }
        // WebP: 52 49 46 46 ... 57 45 42 50
        if bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 {
            return "image/webp"
        }
        // Default to JPEG
        return "image/jpeg"
    }

    // MARK: - Main API Call

    func sendMessage(_ message: String, provider: LLMProvider, model: String, conversationHistory: [Message], imageData: Data? = nil) async throws -> String {
        guard let apiKey = SettingsManager.shared.getAPIKey(for: provider) else {
            throw APIError.missingAPIKey
        }

        let systemPrompt = SettingsManager.shared.getSystemPrompt(for: provider)

        switch provider {
        case .anthropic:
            return try await sendAnthropicMessage(message, model: model, apiKey: apiKey, history: conversationHistory, systemPrompt: systemPrompt, imageData: imageData)
        case .openAI:
            return try await sendOpenAIMessage(message, model: model, apiKey: apiKey, history: conversationHistory, systemPrompt: systemPrompt, imageData: imageData)
        case .google:
            return try await sendGoogleMessage(message, model: model, apiKey: apiKey, history: conversationHistory, systemPrompt: systemPrompt, imageData: imageData)
        case .grok:
            return try await sendGrokMessage(message, model: model, apiKey: apiKey, history: conversationHistory, systemPrompt: systemPrompt)
        }
    }

    // MARK: - Multi-Model API Call

    func sendMessageToAll(_ message: String, conversationHistory: [Message], imageData: Data? = nil) async -> [ProviderResponse] {
        var responses: [ProviderResponse] = []

        // Send to all providers concurrently
        await withTaskGroup(of: ProviderResponse?.self) { group in
            for provider in LLMProvider.allCases {
                // Only send if API key is configured
                guard SettingsManager.shared.hasAPIKey(for: provider) else { continue }

                // Skip Grok for images (doesn't support vision)
                if imageData != nil && provider == .grok { continue }

                let model = provider.models.first ?? ""

                group.addTask {
                    do {
                        let response = try await self.sendMessage(
                            message,
                            provider: provider,
                            model: model,
                            conversationHistory: conversationHistory,
                            imageData: imageData
                        )
                        return ProviderResponse(provider: provider, model: model, content: response)
                    } catch {
                        // Return error as response content
                        let errorMessage = "Error: \(error.localizedDescription)"
                        return ProviderResponse(provider: provider, model: model, content: errorMessage)
                    }
                }
            }

            for await response in group {
                if let response = response {
                    responses.append(response)
                }
            }
        }

        // Sort by provider order
        return responses.sorted { $0.provider.rawValue < $1.provider.rawValue }
    }

    // MARK: - Anthropic API

    private func sendAnthropicMessage(_ message: String, model: String, apiKey: String, history: [Message], systemPrompt: String?, imageData: Data? = nil) async throws -> String {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        // Convert model name to API model ID
        let modelId = getAnthropicModelId(model)

        // Build conversation history (extract relevant provider response from multi-model messages)
        var messages: [[String: Any]] = []
        for msg in history {
            if msg.isMultiModel {
                // For multi-model messages, extract this provider's response
                if let responses = msg.multiResponses,
                   let providerResponse = responses.first(where: { $0.provider == .anthropic }) {
                    messages.append([
                        "role": "assistant",
                        "content": providerResponse.content
                    ])
                }
            } else {
                messages.append([
                    "role": msg.isUser ? "user" : "assistant",
                    "content": msg.content
                ])
            }
        }

        // Add current message with optional image
        if let imageData = imageData {
            let base64Image = imageData.base64EncodedString()
            let mimeType = detectImageMimeType(imageData)
            messages.append([
                "role": "user",
                "content": [
                    [
                        "type": "image",
                        "source": [
                            "type": "base64",
                            "media_type": mimeType,
                            "data": base64Image
                        ]
                    ],
                    [
                        "type": "text",
                        "text": message
                    ]
                ]
            ])
        } else {
            messages.append([
                "role": "user",
                "content": message
            ])
        }

        var body: [String: Any] = [
            "model": modelId,
            "max_tokens": 4096,
            "messages": messages
        ]

        // Add system prompt if provided (Anthropic uses "system" parameter)
        if let systemPrompt = systemPrompt, !systemPrompt.isEmpty {
            body["system"] = systemPrompt
        }

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

    private func sendOpenAIMessage(_ message: String, model: String, apiKey: String, history: [Message], systemPrompt: String?, imageData: Data? = nil) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        // Convert model name to API model ID
        let modelId = getOpenAIModelId(model)

        // Build conversation history
        var messages: [[String: Any]] = []

        // Add system prompt as first message if provided (OpenAI uses role "system")
        if let systemPrompt = systemPrompt, !systemPrompt.isEmpty {
            messages.append([
                "role": "system",
                "content": systemPrompt
            ])
        }

        for msg in history {
            if msg.isMultiModel {
                // For multi-model messages, extract this provider's response
                if let responses = msg.multiResponses,
                   let providerResponse = responses.first(where: { $0.provider == .openAI }) {
                    messages.append([
                        "role": "assistant",
                        "content": providerResponse.content
                    ])
                }
            } else {
                messages.append([
                    "role": msg.isUser ? "user" : "assistant",
                    "content": msg.content
                ])
            }
        }

        // Add current message with optional image
        if let imageData = imageData {
            let base64Image = imageData.base64EncodedString()
            let mimeType = detectImageMimeType(imageData)
            messages.append([
                "role": "user",
                "content": [
                    [
                        "type": "image_url",
                        "image_url": [
                            "url": "data:\(mimeType);base64,\(base64Image)"
                        ]
                    ],
                    [
                        "type": "text",
                        "text": message
                    ]
                ]
            ])
        } else {
            messages.append([
                "role": "user",
                "content": message
            ])
        }

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

    private func sendGoogleMessage(_ message: String, model: String, apiKey: String, history: [Message], systemPrompt: String?, imageData: Data? = nil) async throws -> String {
        // Convert model name to API model ID
        let modelId = getGoogleModelId(model)

        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(modelId):generateContent?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        // Build conversation history
        var contents: [[String: Any]] = []

        for msg in history {
            if msg.isMultiModel {
                // For multi-model messages, extract this provider's response
                if let responses = msg.multiResponses,
                   let providerResponse = responses.first(where: { $0.provider == .google }) {
                    contents.append([
                        "role": "model",
                        "parts": [["text": providerResponse.content]]
                    ])
                }
            } else {
                contents.append([
                    "role": msg.isUser ? "user" : "model",
                    "parts": [["text": msg.content]]
                ])
            }
        }

        // Add current message with optional image
        if let imageData = imageData {
            let base64Image = imageData.base64EncodedString()
            let mimeType = detectImageMimeType(imageData)
            contents.append([
                "role": "user",
                "parts": [
                    [
                        "inlineData": [
                            "mimeType": mimeType,
                            "data": base64Image
                        ]
                    ],
                    ["text": message]
                ]
            ])
        } else {
            contents.append([
                "role": "user",
                "parts": [["text": message]]
            ])
        }

        var body: [String: Any] = [
            "contents": contents
        ]

        // Add system prompt if provided (Google uses systemInstruction)
        if let systemPrompt = systemPrompt, !systemPrompt.isEmpty {
            body["systemInstruction"] = [
                "parts": [["text": systemPrompt]]
            ]
        }

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

    private func sendGrokMessage(_ message: String, model: String, apiKey: String, history: [Message], systemPrompt: String?) async throws -> String {
        let url = URL(string: "https://api.x.ai/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        // Convert model name to API model ID
        let modelId = getGrokModelId(model)

        // Build conversation history
        var messages: [[String: Any]] = []

        // Add system prompt as first message if provided (Grok uses role "system")
        if let systemPrompt = systemPrompt, !systemPrompt.isEmpty {
            messages.append([
                "role": "system",
                "content": systemPrompt
            ])
        }

        for msg in history {
            if msg.isMultiModel {
                // For multi-model messages, extract this provider's response
                if let responses = msg.multiResponses,
                   let providerResponse = responses.first(where: { $0.provider == .grok }) {
                    messages.append([
                        "role": "assistant",
                        "content": providerResponse.content
                    ])
                }
            } else {
                messages.append([
                    "role": msg.isUser ? "user" : "assistant",
                    "content": msg.content
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
        case "Claude Opus 4.6":
            return "claude-opus-4-6-20260205"
        case "Claude Sonnet 4.5":
            return "claude-sonnet-4-5-20250929"
        case "Claude Opus 4.1":
            return "claude-opus-4-1-20250805"
        default:
            return "claude-opus-4-6-20260205"
        }
    }

    private func getOpenAIModelId(_ modelName: String) -> String {
        switch modelName {
        case "GPT-4.1":
            return "gpt-4.1"
        case "GPT-4.1 Mini":
            return "gpt-4.1-mini"
        case "GPT-4o":
            return "gpt-4o"
        case "GPT-4o Mini":
            return "gpt-4o-mini"
        default:
            return "gpt-4.1"
        }
    }

    private func getGoogleModelId(_ modelName: String) -> String {
        switch modelName {
        case "Gemini 2.5 Flash":
            return "gemini-2.5-flash"
        case "Gemini 2.5 Pro":
            return "gemini-2.5-pro"
        case "Gemini 3 Flash":
            return "gemini-3-flash-preview"
        default:
            return "gemini-2.5-flash"
        }
    }

    private func getGrokModelId(_ modelName: String) -> String {
        switch modelName {
        case "Grok 4.1 Fast":
            return "grok-4-1-fast"
        case "Grok 4":
            return "grok-4-0709"
        case "Grok 3":
            return "grok-3-beta"
        default:
            return "grok-4-1-fast"
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
