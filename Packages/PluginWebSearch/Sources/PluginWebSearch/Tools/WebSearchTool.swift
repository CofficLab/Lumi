import KitAgentTool
import Foundation
import ProviderNetwork
import KitSuperLog
import os

/// 网页搜索工具（KernelCore 体系）
///
/// 由旧版 `LumiAgentTool` 迁移为 `SuperAgentTool`；`kernel.network` 依赖改为
/// `WebSearchRuntime`（主插件 onBoot 注入），移除 `kernel.checkCancellation()`。
public struct WebSearchTool: SuperAgentTool {
    private nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "tool.web-search")
    private let searchClient: (@Sendable (String) async throws -> [WebSearchResult])?

    public let name = "web_search"

    public init(
        searchClient: (@Sendable (String) async throws -> [WebSearchResult])? = nil
    ) {
        self.searchClient = searchClient
    }

    public func description(for language: LanguagePreference) -> String {
        LumiPluginLocalization.string(
            "Search the web for real-time information. Use this tool to find current information, news, or specific data from the internet. Note: This tool is often required to be used alongside web_fetch or web_extractor by certain AI models (e.g., Qwen).",
            bundle: .module
        )
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

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let rawQuery = arguments["query"]?.value as? String else {
            return "Error: Missing required 'query' parameter"
        }
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return "Error: Missing required 'query' parameter"
        }

        let results: [WebSearchResult]
        if let searchClient {
            results = try await searchClient(query)
        } else {
            guard let network = await MainActor.run(body: { WebSearchRuntime.network }) else {
                return "Error: Network service is unavailable."
            }
            results = try await Self.fetchDuckDuckGoResults(query: query, network: network)
        }

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
    private static func fetchDuckDuckGoResults(
        query: String,
        network: any NetworkProviding
    ) async throws -> [WebSearchResult] {
        var components = URLComponents(string: "https://html.duckduckgo.com/html/")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query)
        ]
        guard let url = components.url else { return [] }

        let response = try await network.get(
            url: url,
            headers: ["User-Agent": "Lumi/1.0"],
            timeout: 12
        )
        let data = response.body

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
            .replacingOccurrences(of: "&#x27;", with: "'")
            .replacingOccurrences(of: "&#x2F;", with: "/")
            .replacingOccurrences(of: "&#x60;", with: "`")
            .replacingOccurrences(of: "&nbsp;", with: " ")
    }
}

public enum WebSearchError: Error, LocalizedError {
    case badStatus(Int)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .badStatus(let code):
            return "HTTP \(code)"
        case .invalidResponse:
            return "Invalid response"
        }
    }
}
