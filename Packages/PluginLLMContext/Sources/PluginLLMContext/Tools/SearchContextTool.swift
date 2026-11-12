import Foundation
import KitAgentTool
import LumiLoggingKit
import os
import ProviderLLMContext
import ProviderMessage

/// 「搜索上下文」恢复工具（#1160 Phase C）。
///
/// 在压缩块摘要与原始消息里做大小写不敏感的关键词检索，返回带 ID 的命中片段，
/// 让被折叠丢弃的细节可被发现：命中块摘要后可用 `decompress_context` 还原原文。
/// 纯只读，不改任何状态。
struct SearchContextTool: SuperAgentTool, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.llm-context",
        category: "SearchContextTool"
    )

    static let toolName = "search_context"
    let name: String = Self.toolName

    private static let defaultLimit = 20
    private static let maxLimit = 50
    private static let snippetRadius = 80
    private static let snippetLength = 240

    private let provider: LLMContextProvider

    init(provider: LLMContextProvider) {
        self.provider = provider
    }

    func description(for language: LanguagePreference) -> String {
        """
        Search this conversation's compression-block summaries and original messages for a keyword.

        Compaction distills older messages into summary blocks, so a detail you remember may \
        no longer be verbatim in the prompt. Use this tool to find where it lives: matches in \
        a block summary return the block id (restore the full original text with \
        `decompress_context`); matches in original messages return the message id.

        Read-only. The search is case-insensitive substring matching, not semantic search.
        """
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "query": [
                    "type": "string",
                    "description": "Keyword or phrase to search for (case-insensitive).",
                ],
                "scope": [
                    "type": "string",
                    "enum": ["all", "summaries", "messages"],
                    "description": "Where to search. Defaults to 'all'.",
                ],
                "limit": [
                    "type": "integer",
                    "minimum": 1,
                    "maximum": Self.maxLimit,
                    "description": "Maximum number of matches to return. Defaults to \(Self.defaultLimit).",
                ],
            ],
            "required": ["query"],
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .safe }

    var executionCapability: ToolExecutionCapability { .parallelReadOnly }

    func displayDescription(for arguments: [String: ToolArgument]) -> String {
        let query = arguments["query"]?.value as? String ?? ""
        return query.isEmpty ? "Search context" : "Search context: \(query)"
    }

    func executeResult(
        context: ToolExecutionContext,
        arguments: [String: ToolArgument]
    ) async throws -> ToolCallResult {
        let conversationID = context.conversationID
        guard let raw = arguments["query"]?.value as? String else {
            throw ToolExecutionError.executionFailed(toolName: name, reason: "Missing 'query' argument")
        }
        let query = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            throw ToolExecutionError.executionFailed(toolName: name, reason: "'query' must not be empty")
        }
        let scope = (arguments["scope"]?.value as? String)?.lowercased() ?? "all"
        let limit = arguments.toolInt("limit", clampedTo: 1 ... Self.maxLimit, default: Self.defaultLimit)

        let history = await provider.contextHistory(for: conversationID)
        let blocks = await provider.compressionBlocks(for: conversationID)
        let ordered = CompressionEngine.ordered(blocks, by: history)

        var matches: [String] = []
        if scope != "messages" {
            for block in ordered {
                guard let snippet = Self.snippet(in: block.summary, query: query) else { continue }
                matches.append("- [block tier \(block.tier)] id \(block.id.uuidString)\n  \(snippet)")
                if matches.count >= limit { break }
            }
        }
        if scope != "summaries" {
            for message in history {
                guard matches.count < limit else { break }
                guard let snippet = Self.snippet(in: message.content, query: query) else { continue }
                matches.append("- [message \(message.role.rawValue)] id \(message.id.uuidString)\n  \(snippet)")
            }
        }

        guard !matches.isEmpty else {
            return ToolCallResult(content: "No matches for \"\(query)\" in this conversation's summaries or messages.")
        }
        return ToolCallResult(content: """
        ## Context Search: "\(query)"

        \(matches.count) match(es). Block ids can be restored with `decompress_context`.

        \(matches.joined(separator: "\n"))
        """)
    }

    /// 取命中位置周围的一段片段；未命中返回 nil。
    ///
    /// 用原文的 caseInsensitive range 定位，偏移量始终落在 `0...content.count`，
    /// prefix/dropFirst 的入参因此天然有界，不会越界。
    private static func snippet(in content: String, query: String) -> String? {
        guard let range = content.range(of: query, options: .caseInsensitive) else { return nil }
        let matchStart = content.distance(from: content.startIndex, to: range.lowerBound)
        let windowStart = max(matchStart - Self.snippetRadius, 0)
        let window = String(content.prefix(windowStart + Self.snippetLength))
        let body = String(window.dropFirst(windowStart))
        let leading = windowStart > 0 ? "…" : ""
        let trailing = windowStart + Self.snippetLength < content.count ? "…" : ""
        return "\(leading)\(body)\(trailing)"
    }
}