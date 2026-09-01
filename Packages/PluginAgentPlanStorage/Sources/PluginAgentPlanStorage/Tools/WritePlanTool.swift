import Foundation
import KitAgentTool

public struct WritePlanTool: SuperAgentTool {
    public let name = "write_plan"
    private let storage: PlanFileStorageService

    public init(storage: PlanFileStorageService) {
        self.storage = storage
    }

    public func description(for language: LanguagePreference) -> String {
        "Write UTF-8 plan content to Lumi's dedicated Agent plan storage. The filename must be relative to that storage directory."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "filename": ["type": "string", "description": "Relative plan filename, for example plan.md or tasks/current.md"],
                "content": ["type": "string", "description": "UTF-8 Markdown or text plan content"],
            ],
            "required": ["filename", "content"],
        ]
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        guard let filename = arguments["filename"]?.value as? String else { return "写入计划" }
        return "写入计划 \(filename)"
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let filename = arguments["filename"]?.value as? String,
              let content = arguments["content"]?.value as? String else {
            throw NSError(domain: "WritePlanTool", code: 400, userInfo: [NSLocalizedDescriptionKey: "filename and content are required"])
        }

        let path = try await storage.write(filename: filename, content: content)
        return "Wrote plan to \(path)"
    }
}
