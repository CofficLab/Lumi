import AgentToolKit
import Foundation
import LumiCoreKit
import StringCatalogKit
import SuperLogKit
import os

/// 清理 xcstrings 文件中废弃 key 的工具
///
/// 当 xcstrings 文件中存在被标记为 stale 的 key 时，AI 可以调用此工具自动清理它们。
public struct CleanStringCatalogTool: SuperAgentTool, SuperLog {
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.editor-preview.clean-string-catalog"
    )
    public nonisolated static let emoji = "🧹"
    public nonisolated static let verbose: Bool = true

    public let name = "clean_string_catalog"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "清理指定 xcstrings 文件中被标记为废弃（stale）的 key。接受 xcstrings 文件的绝对路径作为参数，返回清理结果。"
        case .english:
            return """
    Clean stale keys from a specified xcstrings file. \
    Takes the absolute path to an xcstrings file as parameter and returns the cleanup result.
    """
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "file_path": [
                    "type": "string",
                    "description": "The absolute path to the xcstrings file to clean",
                ],
            ],
            "required": ["file_path"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        let filePath = arguments["file_path"]?.value as? String ?? "unknown"
        let fileName = URL(fileURLWithPath: filePath).lastPathComponent
        return "清理 \(fileName) 中的废弃 key"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .medium }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        try context.checkCancellation()

        guard let filePath = arguments["file_path"]?.value as? String else {
            return LumiPluginLocalization.string("Error: file_path is required", bundle: .module)
        }

        let fileURL = URL(fileURLWithPath: filePath)

        // 验证文件扩展名
        guard fileURL.pathExtension.lowercased() == "xcstrings" else {
            return String(
                format: LumiPluginLocalization.string("Error: file is not an xcstrings file: %@", bundle: .module),
                filePath
            )
        }

        // 验证文件存在
        guard FileManager.default.fileExists(atPath: filePath) else {
            return String(
                format: LumiPluginLocalization.string("Error: file not found: %@", bundle: .module),
                filePath
            )
        }

        // 读取文件内容
        let source: String
        do {
            source = try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            return String(
                format: LumiPluginLocalization.string("Error: failed to read file: %@", bundle: .module),
                error.localizedDescription
            )
        }

        // 执行清理
        let result: StringCatalogCleanResult
        do {
            result = try StringCatalogCleaner.removingStaleEntries(from: source)
        } catch {
            return String(
                format: LumiPluginLocalization.string("Error: failed to clean string catalog: %@", bundle: .module),
                error.localizedDescription
            )
        }

        // 如果没有需要清理的 key
        guard result.removedCount > 0 else {
            return LumiPluginLocalization.string("No stale keys found in the string catalog.", bundle: .module)
        }

        // 写回文件
        do {
            try result.source.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            return String(
                format: LumiPluginLocalization.string("Error: failed to write cleaned content: %@", bundle: .module),
                error.localizedDescription
            )
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)🧹 Cleaned \(result.removedCount) stale keys from \(filePath)")
        }

        return String(
            format: LumiPluginLocalization.string("✅ Cleaned %lld stale key(s) from %@", bundle: .module),
            result.removedCount,
            fileURL.lastPathComponent
        )
    }
}
