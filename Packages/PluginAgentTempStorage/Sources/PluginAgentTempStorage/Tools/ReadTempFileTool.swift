import KitAgentTool
import Foundation
import KitLocalization

/// 读取临时文件工具
struct ReadTempFileTool: SuperAgentTool {
    let name = "read_temp_file"

    func description(for language: LanguagePreference) -> String {
        LumiPluginLocalization.string(
            "Read UTF-8 text from a file in the agent temp storage directory.",
            bundle: .module
        )
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "filename": [
                    "type": "string",
                    "description": "Relative filename within temp storage",
                ],
            ],
            "required": ["filename"],
        ]
    }

    func displayDescription(for arguments: [String: ToolArgument]) -> String {
        guard let filename = arguments["filename"]?.value as? String else {
            return "Read temp file"
        }
        return "Read temp file \(filename)"
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let filename = arguments["filename"]?.value as? String else {
            throw NSError(
                domain: "ReadTempFileTool",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Missing filename"]
            )
        }

        return try await TempFileStorageService.shared.read(filename: filename)
    }
}
