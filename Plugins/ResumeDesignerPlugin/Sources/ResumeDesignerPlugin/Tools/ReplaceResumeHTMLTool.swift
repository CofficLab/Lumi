import Foundation
import KernelLumi
import ResumeKit

public struct ReplaceResumeHTMLTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "resume_replace_html",
        displayName: "Replace resume HTML",
        description: "Replace the complete HTML document of one resume, validating it before saving."
    )
    public init() {}
    public var inputSchema: LumiJSONValue {
        var properties = ResumeToolSupport.baseProperties()
        properties["html"] = ["type": "string", "description": "Complete deterministic HTML document."]
        return ["type": "object", "properties": .object(properties), "required": ["resumeId", "html"]]
    }
    public func riskLevel(arguments: [String: LumiJSONValue], kernel: KernelLumi) -> LumiCommandRiskLevel { .medium }
    public func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        let scope = try await ResumeToolSupport.resolveScope(arguments, kernel: kernel)
        let resumeID = try ResumeToolSupport.required("resumeId", arguments)
        let html = try ResumeToolSupport.required("html", arguments)
        let resolved = try ResumeToolSupport.store.replaceHTML(
            html,
            storagePath: try await ResumeToolSupport.storagePath(for: scope),
            slug: resumeID
        )
        await ResumeToolSupport.notify(scope: scope, resumeID: resumeID)
        return "Replaced resume HTML (scope=\(scope.rawValue), resumeId=\(resumeID), \(html.utf8.count) bytes).\nNext: run resume_lint and resume_preview_page to verify."
    }
}
