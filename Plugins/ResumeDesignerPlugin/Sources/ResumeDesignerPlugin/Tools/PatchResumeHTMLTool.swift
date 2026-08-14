import Foundation
import KernelLumi
import ResumeKit

public struct PatchResumeHTMLTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "resume_patch_html",
        displayName: "Patch resume HTML",
        description: "Apply an atomic batch of exact, unique text replacements to resume HTML, then validate the complete result."
    )
    public init() {}
    public var inputSchema: LumiJSONValue {
        var properties = ResumeToolSupport.baseProperties()
        properties["operations"] = ["type": "array", "minItems": 1, "maxItems": 20, "items": ["type": "object", "properties": ["oldText": ["type": "string"], "newText": ["type": "string"]], "required": ["oldText", "newText"]]]
        return ["type": "object", "properties": .object(properties), "required": ["resumeId", "operations"]]
    }
    public func riskLevel(arguments: [String: LumiJSONValue], kernel: KernelLumi) -> LumiCommandRiskLevel { .medium }
    public func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        guard case .array(let rawOperations) = arguments["operations"], !rawOperations.isEmpty, rawOperations.count <= 20 else {
            throw ResumeToolSupport.ToolArgumentError.invalid("operations")
        }
        let operations = try rawOperations.map { value -> ResumePatchOperation in
            guard case .object(let object) = value,
                  let oldText = object["oldText"]?.stringValue,
                  let newText = object["newText"]?.stringValue,
                  !oldText.isEmpty else { throw ResumeToolSupport.ToolArgumentError.invalid("operations") }
            return .init(oldText: oldText, newText: newText)
        }
        let scope = try await ResumeToolSupport.resolveScope(arguments, kernel: kernel)
        let resumeID = try ResumeToolSupport.required("resumeId", arguments)
        _ = try ResumeToolSupport.store.patchHTML(
            operations: operations,
            storagePath: try await ResumeToolSupport.storagePath(for: scope),
            slug: resumeID
        )
        await ResumeToolSupport.notify(scope: scope, resumeID: resumeID)
        return "Applied \(operations.count) HTML patches atomically (scope=\(scope.rawValue)).\nCall resume_preview_page to inspect the rendered result."
    }
}
