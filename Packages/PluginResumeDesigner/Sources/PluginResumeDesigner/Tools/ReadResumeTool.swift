import AgentToolKit
import Foundation
import ResumeKit

public struct ReadResumeTool: SuperAgentTool {
    public let name = "resume_read"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Read one resume's manifest metadata (title, paper, template, timestamps)."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        ["type": "object", "properties": ResumeToolSupport.baseProperties(), "required": ["resumeId"]]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "Read resume"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let resume = try ResumeToolSupport.store.readResume(
            storagePath: try await ResumeToolSupport.storagePath(),
            slug: try ResumeToolSupport.required("resumeId", arguments)
        )
        return ResumeToolSupport.resumeSummary(resume.document)
    }
}
