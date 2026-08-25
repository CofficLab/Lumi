import KitAgentTool
import Foundation
import KitResume

public struct PatchResumeHTMLTool: SuperAgentTool {
    public let name = "resume_patch_html"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Apply an atomic batch of exact, unique text replacements to resume HTML, then validate the complete result."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        var properties = ResumeToolSupport.baseProperties()
        properties["operations"] = [
            "type": "array",
            "minItems": 1,
            "maxItems": 20,
            "items": [
                "type": "object",
                "properties": [
                    "oldText": ["type": "string"],
                    "newText": ["type": "string"],
                ],
                "required": ["oldText", "newText"],
            ],
        ]
        return ["type": "object", "properties": properties, "required": ["resumeId", "operations"]]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "Patch resume HTML"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let rawOperations = ResumeToolSupport.array(arguments, "operations")
        guard !rawOperations.isEmpty, rawOperations.count <= 20 else {
            throw ResumeToolSupport.ResumeToolArgumentError.invalid("operations")
        }
        let operations = try rawOperations.map { raw -> ResumePatchOperation in
            guard let object = raw as? [String: Any],
                  let oldText = object["oldText"] as? String,
                  let newText = object["newText"] as? String,
                  !oldText.isEmpty else {
                throw ResumeToolSupport.ResumeToolArgumentError.invalid("operations")
            }
            return .init(oldText: oldText, newText: newText)
        }
        let resumeID = try ResumeToolSupport.required("resumeId", arguments)
        _ = try ResumeToolSupport.store.patchHTML(
            operations: operations,
            storagePath: try await ResumeToolSupport.storagePath(),
            slug: resumeID
        )
        await ResumeToolSupport.notify(resumeID: resumeID)
        return "Applied \(operations.count) HTML patches atomically.\nCall resume_preview_page to inspect the rendered result."
    }
}
