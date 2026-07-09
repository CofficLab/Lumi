import AgentToolKit
import Foundation
import LumiCoreKit
import StringCatalogKit
import SuperLogKit
import os

/// 检查 xcstrings 文件问题的工具
///
/// 接受一个 xcstrings 文件的绝对路径，检测并报告以下问题：
/// - 废弃（stale）的 key
/// - 缺失翻译
/// - 未实际翻译（翻译值与 key 相同）
/// - 占位符不匹配
public struct InspectStringCatalogTool: SuperAgentTool, SuperLog {
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.editor-preview.inspect-string-catalog"
    )
    public nonisolated static let emoji = "🔍"
    public nonisolated static let verbose: Bool = true

    public let name = "inspect_string_catalog"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return """
            检查指定 xcstrings 文件中存在的问题。接受 xcstrings 文件的绝对路径作为参数，\
            检测并报告废弃 key、缺失翻译、未翻译内容等问题。仅做检查，不会修改文件。
            """
        case .english:
            return """
            Inspect issues in a specified xcstrings file. \
            Takes the absolute path to an xcstrings file as parameter, \
            detects and reports stale keys, missing translations, untranslated entries, etc. \
            Read-only — does not modify the file.
            """
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "file_path": [
                    "type": "string",
                    "description": "The absolute path to the xcstrings file to inspect",
                ],
            ],
            "required": ["file_path"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        let filePath = arguments["file_path"]?.value as? String ?? "unknown"
        let fileName = URL(fileURLWithPath: filePath).lastPathComponent
        return "检查 \(fileName) 中的翻译问题"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }

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

        // 解析 xcstrings
        let catalog: StringCatalog
        do {
            catalog = try StringCatalogParser.parse(source)
        } catch {
            return String(
                format: LumiPluginLocalization.string("Error: failed to parse xcstrings file: %@", bundle: .module),
                error.localizedDescription
            )
        }

        // 收集所有问题
        var sections: [String] = []

        // 1. 基本信息
        let activeCount = catalog.entries.count - catalog.staleEntryCount
        sections.append(
            String(
                format: LumiPluginLocalization.string(
                    "File: %@\nSource language: %@ | Languages: %d | Active entries: %d | Stale entries: %d",
                    bundle: .module
                ),
                fileURL.lastPathComponent,
                catalog.sourceLanguage,
                catalog.languages.count,
                activeCount,
                catalog.staleEntryCount
            )
        )

        // 2. 废弃 key
        if !catalog.staleEntryKeys.isEmpty {
            let header = String(
                format: LumiPluginLocalization.string(
                    "\n⚠️ Stale keys (%d):",
                    bundle: .module
                ),
                catalog.staleEntryKeys.count
            )
            let keys = catalog.staleEntryKeys.map { "  • \($0)" }.joined(separator: "\n")
            sections.append("\(header)\n\(keys)")
        }

        // 3. 翻译问题（缺失 + 未翻译）
        let translationIssues = catalog.translationIssues
        if !translationIssues.isEmpty {
            let byLanguage = Dictionary(grouping: translationIssues.issues, by: \.language)
            let sortedLanguages = byLanguage.keys.sorted()

            for language in sortedLanguages {
                guard let issues = byLanguage[language] else { continue }
                let missingKeys = issues.filter { $0.kind == .missing }.map(\.key).sorted()
                let untranslatedKeys = issues.filter { $0.kind == .untranslated }.map(\.key).sorted()

                var parts: [String] = []

                if !missingKeys.isEmpty {
                    let header = String(
                        format: LumiPluginLocalization.string(
                            "\n🚫 Missing translations for \"%@\" (%d):",
                            bundle: .module
                        ),
                        language,
                        missingKeys.count
                    )
                    let keys = missingKeys.map { "  • \($0)" }.joined(separator: "\n")
                    parts.append("\(header)\n\(keys)")
                }

                if !untranslatedKeys.isEmpty {
                    let header = String(
                        format: LumiPluginLocalization.string(
                            "\n⚠️ Untranslated entries for \"%@\" (%d) — value equals key:",
                            bundle: .module
                        ),
                        language,
                        untranslatedKeys.count
                    )
                    let keys = untranslatedKeys.map { "  • \($0)" }.joined(separator: "\n")
                    parts.append("\(header)\n\(keys)")
                }

                if !parts.isEmpty {
                    sections.append(parts.joined(separator: "\n"))
                }
            }
        }

        // 汇总
        let totalIssues = catalog.staleEntryCount + translationIssues.totalCount
        if totalIssues == 0 {
            sections.append(
                LumiPluginLocalization.string("\n✅ No issues found.", bundle: .module)
            )
        } else {
            sections.append(
                String(
                    format: LumiPluginLocalization.string(
                        "\n📊 Total issues: %d (stale: %d, missing: %d, untranslated: %d)",
                        bundle: .module
                    ),
                    totalIssues,
                    catalog.staleEntryCount,
                    translationIssues.issues.filter { $0.kind == .missing }.count,
                    translationIssues.issues.filter { $0.kind == .untranslated }.count
                )
            )
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)🔍 Inspected \(filePath): \(totalIssues) issues found")
        }

        return sections.joined(separator: "\n")
    }
}
