import AgentToolKit
import Foundation
import ResumeKit

public struct ReplaceResumeHTMLTool: SuperAgentTool {
    public let name = "resume_replace_html"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Replace the complete HTML document of one resume, validating it before saving."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        var properties = ResumeToolSupport.baseProperties()
        properties["html"] = ["type": "string", "description": "Complete deterministic HTML document."]
        return ["type": "object", "properties": properties, "required": ["resumeId", "html"]]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "Replace resume HTML"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let resumeID = try ResumeToolSupport.required("resumeId", arguments)
        let html = try ResumeToolSupport.required("html", arguments)
        _ = try ResumeToolSupport.store.replaceHTML(
            html,
            storagePath: try await ResumeToolSupport.storagePath(),
            slug: resumeID
        )
        await ResumeToolSupport.notify(resumeID: resumeID)
        return "Replaced resume HTML (resumeId=\(resumeID), \(html.utf8.count) bytes).\nNext: run resume_lint and resume_preview_page to verify."
    }
}
