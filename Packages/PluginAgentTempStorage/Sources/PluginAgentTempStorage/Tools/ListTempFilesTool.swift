import AgentToolKit
import Foundation
import LocalizationKit

/// 列出临时文件工具
struct ListTempFilesTool: SuperAgentTool {
    let name = "list_temp_files"

    func description(for language: LanguagePreference) -> String {
        LumiPluginLocalization.string(
            "List files in the agent temp storage directory with paths and modification times.",
            bundle: .module
        )
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        ["type": "object", "properties": [:]]
    }

    func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "List temp files"
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        let files = try await TempFileStorageService.shared.listFiles()
        let directory = await TempFileStorageService.shared.storageDirectoryPath
        let retentionDays = AgentTempStoragePluginLocalStore.shared.retentionDays

        guard !files.isEmpty else {
            return "No temp files. Storage directory: \(directory)\nRetention: \(retentionDays) days"
        }

        let formatter = ISO8601DateFormatter()
        let lines = files.map { file in
            let date = formatter.string(from: file.modifiedAt)
            return "- \(file.name) (\(file.size) bytes, modified \(date))\n  path: \(file.path)"
        }
        return """
        \(files.count) temp file(s). Retention: \(retentionDays) days
        Storage directory: \(directory)

        \(lines.joined(separator: "\n"))
        """
    }
}
