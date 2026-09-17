import Foundation
import KitAgentTool
import KitPrototype

/// 对一屏 HTML 应用一批精确、唯一的文本替换（原子操作）。
public struct PatchPrototypeHTMLTool: SuperAgentTool {
    public let name = "prototype_patch_html"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Apply an atomic batch of exact, unique text replacements to one screen's HTML, then validate the complete result. Each oldText must occur exactly once; if any entry fails, nothing is written."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        var properties = PrototypeToolSupport.baseProperties(includeScreen: true)
        properties["operations"] = [
            "type": "array",
            "minItems": 1,
            "maxItems": 20,
            "items": [
                "type": "object",
                "properties": ["oldText": ["type": "string"], "newText": ["type": "string"]],
                "required": ["oldText", "newText"],
            ],
        ]
        return ["type": "object", "properties": properties, "required": ["projectId", "screenId", "operations"]]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        PrototypeToolSupport.localized(PrototypeToolSupport.language, en: "Patch screen HTML", zh: "修补屏幕 HTML")
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let rawOperations = arguments["operations"]?.value as? [Any],
              !rawOperations.isEmpty, rawOperations.count <= 20 else {
            throw PrototypeToolSupport.ToolArgumentError.invalid("operations")
        }
        let operations = try rawOperations.map { value -> PrototypePatchOperation in
            guard let object = value as? [String: Any],
                  let oldText = object["oldText"] as? String,
                  let newText = object["newText"] as? String,
                  !oldText.isEmpty else { throw PrototypeToolSupport.ToolArgumentError.invalid("operations") }
            return .init(oldText: oldText, newText: newText)
        }
        let projectID = try PrototypeToolSupport.required("projectId", arguments)
        let screenID = try PrototypeToolSupport.required("screenId", arguments)
        let resolved = try PrototypeToolSupport.store.patchScreenHTML(
            operations: operations,
            storagePath: try await PrototypeToolSupport.storagePath(),
            projectSlug: projectID,
            screenSlug: screenID
        )
        await PrototypeToolSupport.notify(projectID: projectID, screenID: screenID)
        return "Applied \(operations.count) HTML patches atomically.\n"
            + "\(PrototypeToolSupport.screenSummary(resolved.screen))\n"
            + "Call prototype_preview_screen to inspect the rendered result."
    }
}
