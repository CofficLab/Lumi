import Foundation
import KitAgentTool
import LumiLoggingKit
import os
import ProviderLLMContext
import ProviderMessage

/// 「解压缩上下文块」恢复工具（#1160 Phase C）。
///
/// 沿块血缘（`sourceMessageIDs` / `sourceBlockIDs`）回溯到原始消息，把完整源文本
/// **写到磁盘**并返回文件路径 + 简短预览，而不是把全文重新塞回 prompt——这样既恢复
/// 了保真度，又不破坏 provider 前缀缓存（issue 的 decompress-to-file 方案）。
///
/// 只读会话数据；唯一的副作用是往插件自己的数据目录写一个还原文件。
struct DecompressContextTool: SuperAgentTool, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.llm-context",
        category: "DecompressContextTool"
    )

    static let toolName = "decompress_context"
    let name: String = Self.toolName

    /// 预览正文的最大字符数；完整内容在文件里，预览只够模型判断是否值得读取。
    private static let previewChars = 1_200

    private let provider: LLMContextProvider
    /// 还原文件输出目录；缺少持久化存储时为 nil，工具会明确报错而不是静默降级。
    private let directory: URL?

    init(provider: LLMContextProvider, directory: URL?) {
        self.provider = provider
        self.directory = directory
    }

    func description(for language: LanguagePreference) -> String {
        """
        Restore the original messages behind one compression block to a file on disk.

        Compaction folds older messages into immutable summary blocks. When you need the \
        exact original wording (an audit, a precise error string, a constraint that the \
        summary distilled away), use this tool with a block id from `context_status` or \
        `search_context`. It writes the full source text to a file and returns the path \
        plus a short preview; read the file with the file-reading tool to inspect it.

        The original messages are NOT re-injected into the conversation, so the cached \
        prompt prefix stays intact. Blocks migrated from the legacy rolling summary have \
        no per-message lineage and cannot be decompressed; use `search_context` instead.
        """
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "blockID": [
                    "type": "string",
                    "description": "UUID of the compression block to restore (from context_status or search_context).",
                ],
            ],
            "required": ["blockID"],
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }

    var executionCapability: ToolExecutionCapability { .serialSideEffect }

    func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "Decompress context block"
    }

    func executeResult(
        context: ToolExecutionContext,
        arguments: [String: ToolArgument]
    ) async throws -> ToolCallResult {
        let conversationID = context.conversationID
        guard let raw = arguments["blockID"]?.value as? String,
              let blockID = UUID(uuidString: raw.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw ToolExecutionError.executionFailed(toolName: name, reason: "Missing or invalid 'blockID' argument")
        }
        guard let directory else {
            throw ToolExecutionError.executionFailed(toolName: name, reason: "Decompression storage is unavailable")
        }

        let blocks = await provider.compressionBlocks(for: conversationID)
        guard let block = blocks.first(where: { $0.id == blockID }) else {
            throw ToolExecutionError.executionFailed(
                toolName: name,
                reason: "Block \(blockID.uuidString) was not found in this conversation"
            )
        }

        let sourceIDs = CompressionEngine.sourceMessageIDs(of: blockID, in: blocks)
        guard !sourceIDs.isEmpty else {
            return ToolCallResult(content: """
            ## Block Has No Restorable Lineage

            Block \(blockID.uuidString) (tier \(block.tier)) was migrated from the legacy rolling \
            summary, which did not record per-message lineage. Its original messages cannot be \
            reconstructed. Use `search_context` to look for the detail you need, or read the \
            block summary below:

            \(block.summary)
            """)
        }

        var restored: [Message] = []
        for id in sourceIDs {
            if let message = await provider.originalMessage(id: id, in: conversationID) {
                restored.append(message)
            }
        }
        let text = Self.renderSource(restored, block: block)

        let outputDirectory = directory
            .appendingPathComponent(conversationID.uuidString, isDirectory: true)
        let fileURL = outputDirectory.appendingPathComponent("\(blockID.uuidString).md", isDirectory: false)
        do {
            try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            throw ToolExecutionError.executionFailed(
                toolName: name,
                reason: "Could not write decompressed file: \(error.localizedDescription)"
            )
        }

        Self.logger.info("\(Self.t)decompressed block=\(blockID.uuidString, privacy: .public) messages=\(restored.count, privacy: .public)")
        let preview = text.count > Self.previewChars
            ? String(text.prefix(Self.previewChars)) + "\n…[preview truncated; read the file for full text]"
            : text
        return ToolCallResult(content: """
        ## Context Block Decompressed 📂

        Restored \(restored.count) original message(s) from block \(blockID.uuidString) (tier \(block.tier)).

        - **File**: \(fileURL.path)
        - **Covered through message**: \(block.coveredThroughMessageID.uuidString)

        Read the file to inspect the full source text. The originals were not added back to the conversation.

        ### Preview

        \(preview)
        """)
    }

    /// 把原始消息渲染成保真源文本：角色、内容、推理与工具调用/结果都保留。
    private static func renderSource(_ messages: [Message], block: CompressionBlock) -> String {
        var lines: [String] = [
            "# Decompressed context block \(block.id.uuidString)",
            "",
            "Tier: \(block.tier)",
            "Covered through message: \(block.coveredThroughMessageID.uuidString)",
            "",
            "## Summary",
            "",
            block.summary,
            "",
            "## Original messages",
            "",
        ]
        for message in messages {
            lines.append("### [\(message.role.rawValue)] \(message.id.uuidString)")
            lines.append("")
            if !message.content.isEmpty {
                lines.append(message.content)
                lines.append("")
            }
            if let reasoning = message.reasoningContent, !reasoning.isEmpty {
                lines.append("Reasoning:")
                lines.append(reasoning)
                lines.append("")
            }
            for call in message.toolCalls ?? [] {
                lines.append("Tool call \(call.name): \(call.arguments)")
                if let result = call.result {
                    lines.append("Tool result\(result.isError ? " (error)" : ""): \(result.content)")
                }
                lines.append("")
            }
        }
        return lines.joined(separator: "\n")
    }
}