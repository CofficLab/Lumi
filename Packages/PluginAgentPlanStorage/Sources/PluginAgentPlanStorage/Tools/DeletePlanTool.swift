import Foundation
import KitAgentTool

public struct DeletePlanTool: SuperAgentTool {
    public let name = "delete_plan"
    private let storage: PlanFileStorageService

    public init(storage: PlanFileStorageService) {
        self.storage = storage
    }

    public func description(for language: LanguagePreference) -> String {
        "Delete a plan file from Lumi's dedicated Agent plan storage."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": ["filename": ["type": "string", "description": "Relative plan filename to delete"]],
            "required": ["filename"],
        ]
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        guard let filename = arguments["filename"]?.value as? String else { return "删除计划" }
        return "删除计划 \(filename)"
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let filename = arguments["filename"]?.value as? String else {
            throw NSError(domain: "DeletePlanTool", code: 400, userInfo: [NSLocalizedDescriptionKey: "filename is required"])
        }
        try await storage.delete(filename: filename)
        return "Deleted plan \(filename)"
    }
}
