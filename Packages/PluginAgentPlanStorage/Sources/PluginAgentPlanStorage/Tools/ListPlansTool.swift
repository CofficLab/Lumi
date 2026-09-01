import Foundation
import KitAgentTool

public struct ListPlansTool: SuperAgentTool {
    public let name = "list_plans"
    private let storage: PlanFileStorageService

    public init(storage: PlanFileStorageService) {
        self.storage = storage
    }

    public func description(for language: LanguagePreference) -> String {
        "List saved Agent plan files, modification times, and their dedicated storage directory."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        ["type": "object", "properties": [:]]
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String { "列出计划文件" }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let files = await storage.listFiles()
        let header = "Storage directory: \(await storage.storageDirectoryPath)\nRetention: \(await storage.retentionDays) days"
        guard !files.isEmpty else { return "No plan files.\n\(header)" }

        let formatter = ISO8601DateFormatter()
        let rows = files.map {
            "- \($0.name) (\($0.size) bytes, modified \(formatter.string(from: $0.modifiedAt)))"
        }
        return "\(files.count) plan file(s).\n\(header)\n\n\(rows.joined(separator: "\n"))"
    }
}
