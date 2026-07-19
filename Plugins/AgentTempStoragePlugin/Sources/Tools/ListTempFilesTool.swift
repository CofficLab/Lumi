import Foundation
import LumiKernel

struct ListTempFilesTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "list_temp_files",
        displayName: PluginAgentTempStorageLocalization.string("List Temp Files"),
        description: PluginAgentTempStorageLocalization.string(
            "List files in the agent temp storage directory with paths and modification times."
        )
    )

    init() {}

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([:])
        ])
    }

    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
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
