//
//  WebSearchService.swift
//  AIgent
//
//  Created by Joel Dehlin on 2/1/26.
//

import Foundation

// MARK: - Search Result

struct SearchResult: Identifiable {
    let id = UUID()
    let title: String
    let url: String
    let content: String
    let score: Double?
}

// MARK: - Web Search Service

class WebSearchService {
    static let shared = WebSearchService()

    private init() {}

    // MARK: - Main Search Method

    func search(query: String) async throws -> [SearchResult] {
        guard let apiKey = SettingsManager.shared.getTavilyAPIKey() else {
            throw SearchError.missingAPIKey
        }

        return try await searchWithTavily(query: query, apiKey: apiKey)
    }

    // MARK: - Tavily Search API

    private func searchWithTavily(query: String, apiKey: String) async throws -> [SearchResult] {
        let url = URL(string: "https://api.tavily.com/search")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "api_key": apiKey,
            "query": query,
            "search_depth": "basic",
            "include_answer": false,
            "include_raw_content": false,
            "max_results": 5
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SearchError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SearchError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let results = json?["results"] as? [[String: Any]] else {
            throw SearchError.invalidResponse
        }

        return results.compactMap { result -> SearchResult? in
            guard let title = result["title"] as? String,
                  let url = result["url"] as? String,
                  let content = result["content"] as? String else {
                return nil
            }
            let score = result["score"] as? Double
            return SearchResult(title: title, url: url, content: content, score: score)
        }
    }

    // MARK: - Format Results for LLM Context

    func formatResultsForContext(_ results: [SearchResult]) -> String {
        guard !results.isEmpty else { return "" }

        var context = "## Web Search Results\n\n"
        context += "The following information was found from a web search. Use this to inform your response:\n\n"

        for (index, result) in results.enumerated() {
            context += "### [\(index + 1)] \(result.title)\n"
            context += "Source: \(result.url)\n"
            context += "\(result.content)\n\n"
        }

        context += "---\n\n"
        context += "Based on the above search results and your knowledge, please respond to the user's question.\n\n"

        return context
    }

    // MARK: - Format Sources for Display

    func formatSourcesForDisplay(_ results: [SearchResult]) -> String {
        guard !results.isEmpty else { return "" }

        var sources = "\n\n---\n**Sources:**\n"
        for result in results {
            sources += "• [\(result.title)](\(result.url))\n"
        }
        return sources
    }
}

// MARK: - Search Error

enum SearchError: Error, LocalizedError {
    case missingAPIKey
    case invalidResponse
    case httpError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Tavily API key not found. Please add your API key in Settings."
        case .invalidResponse:
            return "Invalid response from search API."
        case .httpError(let statusCode, let message):
            return "Search Error (\(statusCode)): \(message)"
        }
    }
}
