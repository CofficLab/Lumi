import Foundation
import LumiKernel
import FileSystemKit

public struct EditFileTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "edit_file",
        displayName: LumiPluginLocalization.string("Edit File", bundle: .module),
        description: LumiPluginLocalization.string("Perform exact string replacements in a file.", bundle: .module)
    )
    public static let tags: Set<LumiToolTag> = [.fileSystem, .destructive]

    private let editor = WorkspaceFileEditor()

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "file_path": .object([
                    "type": .string("string"),
                    "description": .string("The absolute path to the file to modify")
                ]),
                "old_string": .object([
                    "type": .string("string"),
                    "description": .string("The text to replace")
                ]),
                "new_string": .object([
                    "type": .string("string"),
                    "description": .string("The text to replace it with")
                ]),
                "replace_all": .object([
                    "type": .string("boolean"),
                    "description": .string("Replace all occurrences of old_string (default false)")
                ]),
                "display_name": .object([
                    "type": .string("string"),
                    "description": .string("Short description shown to the user")
                ])
            ]),
            "required": .array([.string("file_path"), .string("old_string"), .string("new_string")])
        ])
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .high
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        guard let filePath = arguments["file_path"]?.stringValue else {
            return "编辑文件"
        }
        return "编辑 \(URL(fileURLWithPath: filePath).lastPathComponent)"
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let filePath = arguments["file_path"]?.stringValue,
              let oldString = arguments["old_string"]?.stringValue,
              let newString = arguments["new_string"]?.stringValue
        else {
            throw NSError(
                domain: "EditFileTool",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Missing required arguments (file_path, old_string, new_string)."]
            )
        }

        if !context.isPathAllowed(filePath) {
            throw NSError(
                domain: "EditFileTool",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "Path access denied: \(filePath)"]
            )
        }

        let replaceAll = arguments["replace_all"]?.boolValue ?? false

        do {
            let outcome = try editor.edit(
                filePath: filePath,
                oldString: oldString,
                newString: newString,
                replaceAll: replaceAll,
                conversationID: context.conversationID,
                readState: ReadFileStateRegistry.shared
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
        } catch let error as WorkspaceFileError {
            throw NSError(
                domain: "EditFileTool",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: error.localizedDescription]
            )
        }
    }
}
