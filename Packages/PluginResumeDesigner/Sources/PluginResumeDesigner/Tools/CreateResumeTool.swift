import AgentToolKit
import Foundation
import ResumeKit

public struct CreateResumeTool: SuperAgentTool {
    public let name = "resume_create"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Create one plugin-managed resume document from a paper preset (a4/letter) and a starting template (classic/modern/minimal/blank)."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        var properties = ResumeToolSupport.baseProperties()
        properties.removeValue(forKey: "resumeId")
        properties["slug"] = ["type": "string", "description": "Lowercase kebab-case resume slug."]
        properties["title"] = ["type": "string", "description": "Usually the candidate's name."]
        properties["paper"] = [
            "type": "string",
            "enum": ResumePaperKind.allCases.map(\.rawValue),
        ]
        properties["template"] = [
            "type": "string",
            "enum": ResumeTemplateKind.allCases.map(\.rawValue),
            "description": "Starting template. Use 'blank' when the user wants a fully custom design.",
        ]
        return ["type": "object", "properties": properties, "required": ["slug", "title", "paper", "template"]]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "Create resume"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let paperRaw = try ResumeToolSupport.required("paper", arguments)
        guard let paper = ResumePaperKind(rawValue: paperRaw.lowercased()) else {
            throw ResumeToolSupport.ResumeToolArgumentError.invalid("paper")
        }
        let templateRaw = try ResumeToolSupport.required("template", arguments)
        guard let template = ResumeTemplateKind(rawValue: templateRaw.lowercased()) else {
            throw ResumeToolSupport.ResumeToolArgumentError.invalid("template")
        }
        let resolved = try ResumeToolSupport.store.createResume(
            storagePath: try await ResumeToolSupport.storagePath(),
            slug: try ResumeToolSupport.required("slug", arguments),
            title: try ResumeToolSupport.required("title", arguments),
            paper: paper,
            template: template
        )
        await ResumeToolSupport.notify(resumeID: resolved.document.id)
        return """
        Created resume.
        \(ResumeToolSupport.resumeSummary(resolved.document))
        Paper CSS size: \(ResumePaperSpec.preset(for: paper).cssWidth)x\(ResumePaperSpec.preset(for: paper).cssHeight) px.
        Next: edit the HTML with resume_replace_html or resume_patch_html, then run resume_lint and resume_preview_page.
        """
    }
}
