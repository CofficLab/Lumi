import Foundation
import KitAgentTool
import LumiLoggingKit
import os
import ProviderLLMContext
import ProviderMessage

/// 「上下文组成报告」恢复工具（#1160 Phase C，acp_status 风格）。
///
/// 报告当前会话的压缩组成：各层 active 块数量、覆盖水位、逐字保留的最近区间、
/// 完整历史与块摘要的估算 token，以及幕后压缩调用的开销。让模型与用户都能看清
/// 「什么被折叠了、什么还在、花了多少」，并据此决定是否调用 decompress/search。
/// 纯只读。
struct ContextStatusTool: SuperAgentTool, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.llm-context",
        category: "ContextStatusTool"
    )

    static let toolName = "context_status"
    let name: String = Self.toolName

    private let provider: LLMContextProvider

    init(provider: LLMContextProvider) {
        self.provider = provider
    }

    func description(for language: LanguagePreference) -> String {
        """
        Report how this conversation's context is currently composed.

        Shows the resident compression blocks grouped by tier, the coverage watermark (the \
        last original message folded into a summary), the verbatim recent zone, estimated \
        token sizes, and the behind-the-scenes compaction cost. Use it to understand what \
        has been compacted before deciding to `search_context` or `decompress_context`.

        Read-only.
        """
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        ["type": "object", "properties": [:]]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .safe }

    var executionCapability: ToolExecutionCapability { .parallelReadOnly }

    func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "Show context composition"
    }

    func executeResult(
        context: ToolExecutionContext,
        arguments: [String: ToolArgument]
    ) async throws -> ToolCallResult {
        let conversationID = context.conversationID
        let history = await provider.contextHistory(for: conversationID)
        let blocks = await provider.compressionBlocks(for: conversationID)
        let ordered = CompressionEngine.ordered(blocks, by: history)

        let tierCounts = Dictionary(grouping: ordered, by: \.tier).mapValues(\.count)
        let tierLines = tierCounts.keys.sorted().map { tier in
            "- tier \(tier): \(tierCounts[tier] ?? 0) block(s)"
        }
        let blockTokens = ordered.reduce(0) { $0 + $1.estimatedTokens }
        let historyTokens = LLMContextTokenEstimator.estimate(messages: history)

        let watermark = CompressionEngine.watermark(ordered)
        let coveredCount: Int
        if let watermark, let index = history.firstIndex(where: { $0.id == watermark }) {
            coveredCount = index + 1
        } else {
            coveredCount = 0
        }
        let recentZone = min(history.count, LLMContextProvider.minimumRecentMessageCount)

        let usage = await provider.auxiliaryUsageEntries(for: conversationID)
        let compaction = usage.filter { $0.purpose == .compaction }
        let spent = compaction.compactMap(\.spentTokens)
        let spentLine = spent.isEmpty
            ? "unavailable"
            : "\(spent.reduce(0, +)) token(s)\(compaction.contains { $0.isEstimated } ? " (partly estimated)" : "")"

        var lines: [String] = [
            "## Context Composition",
            "",
            "- Original messages in history: \(history.count)",
            "- Estimated full-history tokens: \(historyTokens)",
            "- Resident active blocks: \(ordered.count)",
        ]
        lines.append(contentsOf: tierLines.isEmpty ? ["- (no compression blocks yet)"] : tierLines)
        lines.append("- Estimated block-summary tokens: \(blockTokens)")
        if let watermark {
            lines.append("- Coverage watermark: \(watermark.uuidString) (\(coveredCount) message(s) folded)")
        } else {
            lines.append("- Coverage watermark: none (nothing folded yet)")
        }
        lines.append("- Verbatim recent zone: last \(recentZone) message(s)")
        lines.append("")
        lines.append("### Compaction cost (behind the scenes)")
        lines.append("- Calls: \(compaction.count)")
        lines.append("- Spent: \(spentLine)")
        if !ordered.isEmpty {
            lines.append("")
            lines.append("Use `search_context` to find a detail, or `decompress_context` with a block id to restore originals.")
        }
        return ToolCallResult(content: lines.joined(separator: "\n"))
    }
}