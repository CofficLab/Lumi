import Foundation
import KitAgentTool
import KitPrototype

/// 在编辑前读取一屏的完整 HTML。
public struct ReadPrototypeHTMLTool: SuperAgentTool {
    public let name = "prototype_read_html"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Read the full HTML document of one prototype screen before editing it. Always read before patching so the oldText values match exactly."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        ["type": "object", "properties": PrototypeToolSupport.baseProperties(includeScreen: true), "required": ["projectId", "screenId"]]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        PrototypeToolSupport.localized(PrototypeToolSupport.language, en: "Read screen HTML", zh: "读取屏幕 HTML")
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let resolved = try PrototypeToolSupport.store.readScreen(
            storagePath: try await PrototypeToolSupport.storagePath(),
            projectSlug: try PrototypeToolSupport.required("projectId", arguments),
            screenSlug: try PrototypeToolSupport.required("screenId", arguments)
        )
        return "htmlPath=\(resolved.htmlURL.path)\n"
            + "\(PrototypeToolSupport.screenSummary(resolved.screen))\n"
            + "--- HTML ---\n\(resolved.html)"
    }
}
