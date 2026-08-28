import KitAgentTool
import Foundation
import KitResume

public struct ReadResumeHTMLTool: SuperAgentTool {
    public let name = "resume_read_html"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Read the complete HTML source of one resume."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        ["type": "object", "properties": ResumeToolSupport.baseProperties(), "required": ["resumeId"]]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "Read resume HTML"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let resume = try ResumeToolSupport.store.readResume(
            storagePath: try await ResumeToolSupport.storagePath(),
            slug: try ResumeToolSupport.required("resumeId", arguments)
        )
        return "resumeId=\(resume.document.id)\n\(resume.html)"
    }
}
