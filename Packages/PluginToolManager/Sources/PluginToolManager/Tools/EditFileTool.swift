import AgentToolKit
import FileSystemKit
import Foundation

/// 精确替换文件内容（复刻旧版 ToolManagerPlugin 的 EditFileTool）。
public struct EditFileTool: SuperAgentTool, @unchecked Sendable {
    public let name = "edit_file"

    private let editor = WorkspaceFileEditor()

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Perform exact string replacements in a file."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "file_path": ["type": "string", "description": "The absolute path to the file to modify"],
                "old_string": ["type": "string", "description": "The text to replace"],
                "new_string": ["type": "string", "description": "The text to replace it with"],
                "replace_all": ["type": "boolean", "description": "Replace all occurrences of old_string (default false)"],
                "display_name": ["type": "string", "description": "Short description shown to the user"],
            ],
            "required": ["file_path", "old_string", "new_string"],
        ]
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .high }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        guard let filePath = arguments.stringValue("file_path") else { return "编辑文件" }
        return "编辑 \(URL(fileURLWithPath: filePath).lastPathComponent)"
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let filePath = arguments.stringValue("file_path"),
              let oldString = arguments.stringValue("old_string"),
              let newString = arguments.stringValue("new_string")
        else {
            throw NSError(
                domain: "EditFileTool",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Missing required arguments (file_path, old_string, new_string)."]
            )
        }

        let replaceAll = arguments.boolValue("replace_all") ?? false

        do {
            let outcome = try editor.edit(
                filePath: filePath,
                oldString: oldString,
                newString: newString,
                replaceAll: replaceAll
            )
            switch outcome {
            case .createdNewFile:
                return "Created new file: \(filePath)"
            case .wroteEmptyFile:
                return "Wrote content to empty file: \(filePath)"
            case .updated(_, let matchCount, let replaceAll, let diff):
                if replaceAll {
                    return "The file \(filePath) has been updated. All \(matchCount) occurrences were successfully replaced.\n\n\(diff)"
                }
                return "The file \(filePath) has been updated successfully.\n\n\(diff)"
            }
        } catch {
            throw NSError(
                domain: "EditFileTool",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: error.localizedDescription]
            )
        }
    }
}
