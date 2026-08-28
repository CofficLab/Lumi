import KitAgentTool
import Foundation
import KitLocalization

/// 写入临时文件工具
struct WriteTempFileTool: SuperAgentTool {
    let name = "write_temp_file"

    func description(for language: LanguagePreference) -> String {
        LumiPluginLocalization.string(
            "Write UTF-8 text to the agent temp storage directory. Files are auto-deleted after the retention period (default 7 days).",
            bundle: .module
        )
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "filename": [
                    "type": "string",
                    "description": "Relative filename within temp storage, e.g. \"report.md\" or \"exports/data.json\"",
                ],
                "content": [
                    "type": "string",
                    "description": "UTF-8 text content to write",
                ],
            ],
            "required": ["filename", "content"],
        ]
    }

    func displayDescription(for arguments: [String: ToolArgument]) -> String {
        guard let filename = arguments["filename"]?.value as? String else {
            return "Write temp file"
        }
        return "Write temp file \(filename)"
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let filename = arguments["filename"]?.value as? String,
              let content = arguments["content"]?.value as? String
        else {
            throw NSError(
                domain: "WriteTempFileTool",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Missing filename or content"]
            )
        }

        let path = try await TempFileStorageService.shared.write(filename: filename, content: content)
        let directory = await TempFileStorageService.shared.storageDirectoryPath
        return "Wrote \(content.count) characters to \(path)\nStorage directory: \(directory)"
    }
}
