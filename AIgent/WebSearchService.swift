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

    // MARK: - Auto-Detection Keywords

    private let searchTriggerKeywords = [
        // Time-sensitive
        "latest", "recent", "new", "current", "today", "yesterday",
        "this week", "this month", "this year", "now", "just",
        // News/Events
        "news", "update", "announcement", "release", "launched",
        "happened", "event", "breaking",
        // Prices/Data
        "price", "stock", "weather", "score", "result",
        "how much", "cost",
        // Years (current and recent)
        "2024", "2025", "2026",
        // Questions about current state
        "who is the", "what is the current", "is there a",
        "has anyone", "did they", "when did", "when will"
    ]

    // MARK: - Auto-Detection

    func shouldSearch(query: String) -> Bool {
        let lowercased = query.lowercased()

        // Check for trigger keywords
        for keyword in searchTriggerKeywords {
            if lowercased.contains(keyword) {
                return true
            }
        }

        // Check for question patterns that often need current info
        let questionPatterns = [
            "what happened",
            "who won",
            "is .+ still",
            "how many .+ now",
            "what's new"
        ]

        for pattern in questionPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(lowercased.startIndex..., in: lowercased)
                if regex.firstMatch(in: lowercased, range: range) != nil {
                    return true
                }
            }
        }

        return false
    }

    // MARK: - Main Search Method

    func search(query: String) async throws -> [SearchResult] {
        // Try DuckDuckGo first (free, no API key)
        let results = try await searchWithDuckDuckGo(query: query)

        // If DuckDuckGo returns no results and Tavily is configured, try Tavily
        if results.isEmpty, let tavilyKey = SettingsManager.shared.getTavilyAPIKey() {
            return try await searchWithTavily(query: query, apiKey: tavilyKey)
        }

        return results
    }

    // MARK: - DuckDuckGo Search (Free, No API Key)

    private func searchWithDuckDuckGo(query: String) async throws -> [SearchResult] {
        // Use DuckDuckGo's HTML search and parse results
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://html.duckduckgo.com/html/?q=\(encodedQuery)"

        guard let url = URL(string: urlString) else {
            throw SearchError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SearchError.invalidResponse
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw SearchError.invalidResponse
        }

        return parseDuckDuckGoHTML(html)
    }

    private func parseDuckDuckGoHTML(_ html: String) -> [SearchResult] {
        var results: [SearchResult] = []

        // Parse result blocks - DuckDuckGo HTML has class="result"
        let resultPattern = #"<a class="result__a"[^>]*href="([^"]*)"[^>]*>([^<]*)</a>.*?<a class="result__snippet"[^>]*>([^<]*)</a>"#

        // Simpler pattern for title and URL
        let linkPattern = #"<a class="result__a"[^>]*href="([^"]*)"[^>]*>([^<]*)</a>"#
        let snippetPattern = #"<a class="result__snippet"[^>]*>([^<]*)</a>"#

        // Find all result links
        if let linkRegex = try? NSRegularExpression(pattern: linkPattern, options: [.dotMatchesLineSeparators]) {
            let range = NSRange(html.startIndex..., in: html)
            let matches = linkRegex.matches(in: html, range: range)

            for (index, match) in matches.prefix(5).enumerated() {
                guard let urlRange = Range(match.range(at: 1), in: html),
                      let titleRange = Range(match.range(at: 2), in: html) else {
                    continue
                }

                var urlString = String(html[urlRange])
                let title = String(html[titleRange])
                    .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                // DuckDuckGo uses redirect URLs, extract the actual URL
                if urlString.contains("uddg="), let decoded = urlString.removingPercentEncoding {
                    if let uddgRange = decoded.range(of: "uddg=") {
                        let afterUddg = decoded[uddgRange.upperBound...]
                        if let ampRange = afterUddg.range(of: "&") {
                            urlString = String(afterUddg[..<ampRange.lowerBound])
                        } else {
                            urlString = String(afterUddg)
                        }
                        urlString = urlString.removingPercentEncoding ?? urlString
                    }
                }

                // Try to find snippet for this result
                var snippet = "No description available"
                if let snippetRegex = try? NSRegularExpression(pattern: snippetPattern, options: []) {
                    let snippetMatches = snippetRegex.matches(in: html, range: range)
                    if index < snippetMatches.count {
                        if let snippetRange = Range(snippetMatches[index].range(at: 1), in: html) {
                            snippet = String(html[snippetRange])
                                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    }
                }

                guard !title.isEmpty, !urlString.isEmpty else { continue }

                results.append(SearchResult(
                    title: title,
                    url: urlString,
                    content: snippet,
                    score: nil
                ))
            }
        }

        return results
    }

    // MARK: - Tavily Search API (Fallback if configured)

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
    case noResults

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Search API key not found."
        case .invalidResponse:
            return "Invalid response from search API."
        case .httpError(let statusCode, let message):
            return "Search Error (\(statusCode)): \(message)"
        case .noResults:
            return "No search results found."
        }
    }
}
