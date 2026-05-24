import Foundation
import AgentToolKit
import WorkspaceFileKit

/// 文件编辑工具
///
/// 基于精确字符串替换的文件编辑工具。
/// 支持：
/// - 先读后写的安全检查
/// - 智能引号匹配
/// - 原子性文件操作
/// - 详细的 diff 输出
struct EditFileTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "🔧"
    nonisolated static let verbose: Bool = true
    private let editor = WorkspaceFileEditor()
    let name = "edit_file"
    func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return """
在文件中执行精确字符串替换。

用法：
- 编辑前必须在当前对话中使用 `read_file` 读取过该文件。未读取就尝试编辑会报错。
- 从 Read 工具输出中编辑文本时，必须保留精确缩进（tab/空格）；行号前缀之后的内容才是需要匹配的真实文件内容。
- 如果 `old_string` 在文件中不唯一，编辑会失败。请提供更大的上下文让它唯一，或使用 `replace_all` 替换所有匹配项。
- 跨文件内多处替换或重命名字符串时使用 `replace_all`。
- 使用足够小但明确唯一的 old_string；通常 2-4 行相邻内容即可。
"""
        case .english:
            return     """
Performs exact string replacements in files.

Usage:
- The file must have been read with `read_file` in this conversation before editing. This tool will error if you attempt an edit without reading the file.
- When editing text from Read tool output, ensure you preserve the exact indentation (tabs/spaces) — everything after the line number prefix is the actual file content to match.
- The edit will FAIL if `old_string` is not unique in the file. Either provide a larger string with more surrounding context to make it unique or use `replace_all` to change every instance of `old_string`.
- Use `replace_all` for replacing and renaming strings across the file.
- Use the smallest old_string that's clearly unique — usually 2-4 adjacent lines is sufficient.
"""
        }
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        let displayDesc: String
        switch language {
        case .chinese:
            displayDesc = "向用户展示当前操作描述，如：正在编辑 xxx.swift"
        case .english:
            displayDesc = "A short description shown to the user, e.g. \"Editing xxx.swift\""
        }
        return [
            "type": "object",
            "properties": [
                "file_path": [
                    "type": "string",
                    "description": "The absolute path to the file to modify"
                ],
                "old_string": [
                    "type": "string",
                    "description": "The text to replace"
                ],
                "new_string": [
                    "type": "string",
                    "description": "The text to replace it with (must be different from old_string)"
                ],
                "replace_all": [
                    "type": "boolean",
                    "description": "Replace all occurrences of old_string (default false)"
                ],
                "display_name": [
                    "type": "string",
                    "description": displayDesc
                ]
            ],
            "required": ["file_path", "old_string", "new_string"]
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .high
    }

    func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        guard let filePath = arguments["file_path"]?.value as? String,
              let oldString = arguments["old_string"]?.value as? String,
              let newString = arguments["new_string"]?.value as? String else {
            return "Error: Missing required arguments (file_path, old_string, new_string)."
        }

        let replaceAll = arguments["replace_all"]?.value as? Bool ?? false

        if Self.verbose {
            AgentCoreToolsPlugin.logger.info("\(self.t)编辑文件：\((filePath as NSString).expandingTildeInPath)")
        }

        do {
            let outcome = try editor.edit(filePath: filePath, oldString: oldString, newString: newString, replaceAll: replaceAll)
            switch outcome {
            case .createdNewFile:
                if Self.verbose {
                    AgentCoreToolsPlugin.logger.info("\(self.t)创建新文件：\((filePath as NSString).expandingTildeInPath)")
                }
                return "Created new file: \(filePath)"
            case .wroteEmptyFile:
                return "Wrote content to empty file: \(filePath)"
            case .updated(_, let matchCount, let replaceAll, let diff):
                if Self.verbose {
                    AgentCoreToolsPlugin.logger.info("\(self.t)文件编辑成功：\((filePath as NSString).expandingTildeInPath)")
                }

                if replaceAll {
                    return "The file \(filePath) has been updated. All \(matchCount) occurrences were successfully replaced.\n\n\(diff)"
                }

                return "The file \(filePath) has been updated successfully.\n\n\(diff)"
            }
        } catch let error as WorkspaceFileError {
            return "Error: \(error.localizedDescription)"
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
}
