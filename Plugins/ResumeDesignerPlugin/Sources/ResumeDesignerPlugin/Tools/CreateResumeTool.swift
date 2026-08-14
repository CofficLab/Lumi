import Foundation
import KernelLumi
import ResumeKit

public struct CreateResumeTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "resume_create",
        displayName: "Create resume",
        description: "Create one plugin-managed resume document from a paper preset (a4/letter) and a starting template (classic/modern/minimal/blank)."
    )
    public init() {}
    public var inputSchema: LumiJSONValue {
        var properties: [String: LumiJSONValue] = ResumeToolSupport.baseProperties()
        properties.removeValue(forKey: "resumeId")
        properties["slug"] = ["type": "string", "description": "Lowercase kebab-case resume slug."]
        properties["title"] = ["type": "string", "description": "Usually the candidate's name."]
        properties["paper"] = ["type": "string", "enum": .array(ResumePaperKind.allCases.map { LumiJSONValue.string($0.rawValue) })]
        properties["template"] = ["type": "string", "enum": .array(ResumeTemplateKind.allCases.map { LumiJSONValue.string($0.rawValue) }), "description": "Starting template. Use 'blank' when the user wants a fully custom design."]
        return ["type": "object", "properties": .object(properties), "required": ["slug", "title", "paper", "template"]]
    }
    public func riskLevel(arguments: [String: LumiJSONValue], kernel: KernelLumi) -> LumiCommandRiskLevel { .medium }
    public func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        let scope = try await ResumeToolSupport.resolveScope(arguments, kernel: kernel)
        let paperRaw = try ResumeToolSupport.required("paper", arguments)
        guard let paper = ResumePaperKind(rawValue: paperRaw.lowercased()) else {
            throw ResumeToolSupport.ToolArgumentError.invalid("paper")
        }
        let templateRaw = try ResumeToolSupport.required("template", arguments)
        guard let template = ResumeTemplateKind(rawValue: templateRaw.lowercased()) else {
            throw ResumeToolSupport.ToolArgumentError.invalid("template")
        }
        let resolved = try ResumeToolSupport.store.createResume(
            storagePath: try await ResumeToolSupport.storagePath(for: scope),
            slug: try ResumeToolSupport.required("slug", arguments),
            title: try ResumeToolSupport.required("title", arguments),
            paper: paper,
            template: template
        )
        await ResumeToolSupport.notify(scope: scope, resumeID: resolved.document.id)
        return """
        Created resume (scope=\(scope.rawValue)).
        \(ResumeToolSupport.resumeSummary(resolved.document, scope: scope))
        Paper CSS size: \(ResumePaperSpec.preset(for: paper).cssWidth)x\(ResumePaperSpec.preset(for: paper).cssHeight) px.
        Next: edit the HTML with resume_replace_html or resume_patch_html, then run resume_lint and resume_preview_page.
        """
    }
}
