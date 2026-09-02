import Foundation
import KitAgentTool

public struct ReadPlanTool: SuperAgentTool {
    public let name = "read_plan"
    private let storage: PlanFileStorageService

    public init(storage: PlanFileStorageService) {
        self.storage = storage
    }

    public func description(for language: LanguagePreference) -> String {
        "Read UTF-8 content from a plan in Lumi's dedicated Agent plan storage."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": ["filename": ["type": "string", "description": "Relative plan filename"]],
            "required": ["filename"],
        ]
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        guard let filename = arguments["filename"]?.value as? String else { return "读取计划" }
        return "读取计划 \(filename)"
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let filename = arguments["filename"]?.value as? String else {
            throw NSError(domain: "ReadPlanTool", code: 400, userInfo: [NSLocalizedDescriptionKey: "filename is required"])
        }
        return try await storage.read(filename: filename)
    }
}
