import Foundation
import KernelLumi
import StringCatalogKit
import SuperLogKit
import os

/// 清理 xcstrings 文件中废弃 key 的工具
///
/// 当 xcstrings 文件中存在被标记为 stale 的 key 时，AI 可以调用此工具自动清理它们。
public struct CleanStringCatalogTool: LumiAgentTool, SuperLog {
    public static let info = LumiAgentToolInfo(
        id: "clean_string_catalog",
        displayName: "Clean String Catalog",
        description: "Clean stale keys from a specified xcstrings file."
    )

    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.editor-preview.clean-string-catalog"
    )
    public nonisolated static let emoji = "🧹"
    public nonisolated static let verbose: Bool = false

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "file_path": .object([
                    "type": .string("string"),
                    "description": .string("The absolute path to the xcstrings file to clean"),
                ]),
            ]),
            "required": .array([.string("file_path")]),
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        let filePath = arguments["file_path"]?.stringValue ?? "unknown"
        let fileName = URL(fileURLWithPath: filePath).lastPathComponent
        return "清理 \(fileName) 中的废弃 key"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], kernel: KernelLumi) -> LumiCommandRiskLevel {
        .medium
    }

    public func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        try kernel.checkCancellation()

        guard let filePath = arguments["file_path"]?.stringValue else {
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
