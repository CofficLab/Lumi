import AgentToolKit
import Foundation
import SuperLogKit
import os

public struct WebSearchTool: SuperAgentTool, SuperLog {
    public nonisolated static let emoji = "🔍"
    public nonisolated static let verbose: Bool = true
    private nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "tool.web-search")
    private let searchClient: @Sendable (String) async throws -> [WebSearchResult]

    public let name = "web_search"

    public init(
        searchClient: (@Sendable (String) async throws -> [WebSearchResult])? = nil
    ) {
        self.searchClient = searchClient ?? WebSearchTool.fetchDuckDuckGoResults
    }

    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return """
搜索网页以获取实时信息。
使用此工具从互联网查找最新信息、新闻或特定数据。

注意：某些 AI 模型（例如 Qwen）通常要求此工具与 web_fetch 或 web_extractor 配合使用。
"""
        case .english:
            return """
Search the web for real-time information.
Use this tool to find current information, news, or specific data from the internet.

Note: This tool is often required to be used alongside web_fetch or web_extractor by certain AI models (e.g., Qwen).
"""
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "query": [
                    "type": "string",
                    "description": "The search query to find information on the web",
                ],
            ],
            "required": ["query"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "搜索网页"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        guard let rawQuery = arguments["query"]?.value as? String else {
            return "Error: Missing required 'query' parameter"
        }
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return "Error: Missing required 'query' parameter"
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)🔍 Searching for: \(query)")
        }

        try context.checkCancellation()
        let results = try await searchClient(query)
        try context.checkCancellation()

        if results.isEmpty {
            return """
            ## Web Search Results

            **Query**: \(query)
            **Status**: No results found.
            """
        }

        let renderedResults = results.prefix(5).enumerated().map { index, result in
            var lines = [
                "\(index + 1). [\(result.title)](\(result.url))",
            ]
            if let snippet = result.snippet, !snippet.isEmpty {
                lines.append("   \(snippet)")
            }
            return lines.joined(separator: "\n")
        }.joined(separator: "\n\n")

        return """
        ## Web Search Results

        **Query**: \(query)

        \(renderedResults)
        """
    }
}

public struct WebSearchResult: Equatable, Sendable {
    public let title: String
    public let url: String
    public let snippet: String?

    public init(title: String, url: String, snippet: String? = nil) {
        self.title = title
        self.url = url
        self.snippet = snippet
    }
}

extension WebSearchTool {
    private static func fetchDuckDuckGoResults(query: String) async throws -> [WebSearchResult] {
        var components = URLComponents(string: "https://html.duckduckgo.com/html/")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query)
        ]
        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 12
        request.setValue("Lumi/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw WebSearchError.badStatus(httpResponse.statusCode)
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw WebSearchError.invalidResponse
        }

        return parseDuckDuckGoHTML(html)
    }

    static func parseDuckDuckGoHTML(_ html: String) -> [WebSearchResult] {
        let anchors = findResultAnchors(in: html)
        return anchors.enumerated().compactMap { index, anchor in
            let blockEnd = anchors.indices.contains(index + 1) ? anchors[index + 1].range.lowerBound : html.endIndex
            let block = String(html[anchor.range.lowerBound..<blockEnd])
            guard let rawURL = attributeValue("href", in: anchor.tag) else {
                return nil
            }

            let title = cleanHTMLText(anchor.body)
            let url = decodeDuckDuckGoURL(rawURL)

            guard !title.isEmpty, !url.isEmpty else { return nil }

            let snippet = extractSnippet(from: String(block))
            return WebSearchResult(title: title, url: url, snippet: snippet)
        }
    }

    private static func findResultAnchors(in html: String) -> [(range: Range<String.Index>, tag: String, body: String)] {
        guard let regex = try? NSRegularExpression(
            pattern: #"<a\b([^>]*)>(.*?)</a>"#,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return []
        }

        let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
        return regex.matches(in: html, range: nsRange).compactMap { match in
            guard let fullRange = Range(match.range(at: 0), in: html),
                  let tagAttributesRange = Range(match.range(at: 1), in: html),
                  let bodyRange = Range(match.range(at: 2), in: html)
            else {
                return nil
            }

            let tagAttributes = String(html[tagAttributesRange])
            guard let className = attributeValue("class", in: tagAttributes),
                  className.split(separator: " ").contains("result__a")
            else {
                return nil
            }

            return (fullRange, tagAttributes, String(html[bodyRange]))
        }
    }

    private static func attributeValue(_ name: String, in tag: String) -> String? {
        guard let regex = try? NSRegularExpression(
            pattern: #"\b\#(NSRegularExpression.escapedPattern(for: name))\s*=\s*"([^"]*)""#,
            options: [.caseInsensitive]
        ) else {
            return nil
        }

        let nsRange = NSRange(tag.startIndex..<tag.endIndex, in: tag)
        guard let match = regex.firstMatch(in: tag, range: nsRange),
              let valueRange = Range(match.range(at: 1), in: tag)
        else {
            return nil
        }
        return String(tag[valueRange])
    }

    private static func extractSnippet(from block: String) -> String? {
        guard let snippetRange = block.range(of: #"class="result__snippet""#),
              let start = block[snippetRange.upperBound...].firstIndex(of: ">"),
              let endRange = block[start...].range(of: "</a>")
        else {
            return nil
        }

        let rawSnippet = String(block[block.index(after: start)..<endRange.lowerBound])
        let snippet = cleanHTMLText(rawSnippet)
        return snippet.isEmpty ? nil : snippet
    }

    private static func decodeDuckDuckGoURL(_ rawURL: String) -> String {
        let unescaped = decodeHTMLEntities(rawURL)
        guard let components = URLComponents(string: unescaped),
              let redirected = components.queryItems?.first(where: { $0.name == "uddg" })?.value,
              !redirected.isEmpty
        else {
            return unescaped
        }
        return redirected
    }

    private static func cleanHTMLText(_ raw: String) -> String {
        let withoutTags = raw.replacingOccurrences(
            of: #"<[^>]+>"#,
            with: "",
            options: .regularExpression
        )
        return decodeHTMLEntities(withoutTags)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decodeHTMLEntities(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }
}

enum WebSearchError: LocalizedError {
    case badStatus(Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .badStatus(let statusCode):
            "Search request failed with HTTP \(statusCode)."
        case .invalidResponse:
            "Search response could not be decoded."
        }
    }
}
