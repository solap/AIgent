//
//  ImageGenerationService.swift
//  AIgent
//
//  Created by Joel Dehlin on 1/31/26.
//

import Foundation

// MARK: - Image Generation Provider

enum ImageGenProvider: String, CaseIterable, Identifiable, Codable {
    case openAI = "OpenAI"
    case google = "Google"
    case grok = "Grok"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .openAI: return "brain.head.profile"
        case .google: return "g.circle"
        case .grok: return "bolt.circle"
        }
    }

    var modelName: String {
        switch self {
        case .openAI: return "DALL-E 3"
        case .google: return "Imagen 3"
        case .grok: return "Aurora"
        }
    }

    var apiModelId: String {
        switch self {
        case .openAI: return "dall-e-3"
        case .google: return "imagen-3.0-generate-002"
        case .grok: return "grok-2-image"
        }
    }

    // Map to LLMProvider for API key lookup
    var llmProvider: LLMProvider {
        switch self {
        case .openAI: return .openAI
        case .google: return .google
        case .grok: return .grok
        }
    }
}

// MARK: - Generated Image

struct GeneratedImage: Identifiable {
    let id = UUID()
    let provider: ImageGenProvider
    let prompt: String
    let imageData: Data
    let timestamp: Date

    init(provider: ImageGenProvider, prompt: String, imageData: Data) {
        self.provider = provider
        self.prompt = prompt
        self.imageData = imageData
        self.timestamp = Date()
    }
}

// MARK: - Image Generation Response

struct ImageGenResponse: Identifiable {
    let id = UUID()
    let provider: ImageGenProvider
    let imageData: Data?
    let error: String?
    let timestamp: Date

    init(provider: ImageGenProvider, imageData: Data) {
        self.provider = provider
        self.imageData = imageData
        self.error = nil
        self.timestamp = Date()
    }

    init(provider: ImageGenProvider, error: String) {
        self.provider = provider
        self.imageData = nil
        self.error = error
        self.timestamp = Date()
    }
}

// MARK: - Image Generation Service

class ImageGenerationService {
    static let shared = ImageGenerationService()

    private init() {}

    // MARK: - Main API Call

    func generateImage(prompt: String, provider: ImageGenProvider) async throws -> Data {
        guard let apiKey = SettingsManager.shared.getAPIKey(for: provider.llmProvider) else {
            throw APIError.missingAPIKey
        }

        switch provider {
        case .openAI:
            return try await generateWithDALLE(prompt: prompt, apiKey: apiKey)
        case .google:
            return try await generateWithImagen(prompt: prompt, apiKey: apiKey)
        case .grok:
            return try await generateWithAurora(prompt: prompt, apiKey: apiKey)
        }
    }

    // MARK: - Generate All

    func generateImageFromAll(prompt: String) async -> [ImageGenResponse] {
        var responses: [ImageGenResponse] = []

        await withTaskGroup(of: ImageGenResponse?.self) { group in
            for provider in ImageGenProvider.allCases {
                guard SettingsManager.shared.hasAPIKey(for: provider.llmProvider) else { continue }

                group.addTask {
                    do {
                        let imageData = try await self.generateImage(prompt: prompt, provider: provider)
                        return ImageGenResponse(provider: provider, imageData: imageData)
                    } catch {
                        return ImageGenResponse(provider: provider, error: error.localizedDescription)
                    }
                }
            }

            for await response in group {
                if let response = response {
                    responses.append(response)
                }
            }
        }

        return responses.sorted { $0.provider.rawValue < $1.provider.rawValue }
    }

    // MARK: - OpenAI DALL-E 3

    private func generateWithDALLE(prompt: String, apiKey: String) async throws -> Data {
        let url = URL(string: "https://api.openai.com/v1/images/generations")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model": "dall-e-3",
            "prompt": prompt,
            "n": 1,
            "size": "1024x1024",
            "response_format": "b64_json"
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
        guard let dataArray = json?["data"] as? [[String: Any]],
              let firstImage = dataArray.first,
              let b64Json = firstImage["b64_json"] as? String,
              let imageData = Data(base64Encoded: b64Json) else {
            throw APIError.invalidResponse
        }

        return imageData
    }

    // MARK: - Google Imagen 3

    private func generateWithImagen(prompt: String, apiKey: String) async throws -> Data {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/imagen-3.0-generate-002:predict?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "instances": [
                ["prompt": prompt]
            ],
            "parameters": [
                "sampleCount": 1
            ]
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
        guard let predictions = json?["predictions"] as? [[String: Any]],
              let firstPrediction = predictions.first,
              let b64Image = firstPrediction["bytesBase64Encoded"] as? String,
              let imageData = Data(base64Encoded: b64Image) else {
            throw APIError.invalidResponse
        }

        return imageData
    }

    // MARK: - Grok Aurora

    private func generateWithAurora(prompt: String, apiKey: String) async throws -> Data {
        let url = URL(string: "https://api.x.ai/v1/images/generations")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model": "grok-2-image",
            "prompt": prompt,
            "n": 1,
            "response_format": "b64_json"
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
        guard let dataArray = json?["data"] as? [[String: Any]],
              let firstImage = dataArray.first,
              let b64Json = firstImage["b64_json"] as? String,
              let imageData = Data(base64Encoded: b64Json) else {
            throw APIError.invalidResponse
        }

        return imageData
    }
}
