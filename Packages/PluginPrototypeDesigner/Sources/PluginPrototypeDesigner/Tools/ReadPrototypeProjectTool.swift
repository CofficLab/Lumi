import Foundation
import KitAgentTool
import KitPrototype

/// 读取原型项目的结构、设备尺寸与跳转拓扑。
public struct ReadPrototypeProjectTool: SuperAgentTool {
    public let name = "prototype_read_project"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Read prototype project metadata, device canvas, screen order, and the navigation topology. Use this instead of reading every screen's HTML to understand the structure."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        ["type": "object", "properties": PrototypeToolSupport.baseProperties(), "required": ["projectId"]]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        PrototypeToolSupport.localized(PrototypeToolSupport.language, en: "Read prototype", zh: "读取原型项目")
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let project = try PrototypeToolSupport.store.readProject(
            storagePath: try await PrototypeToolSupport.storagePath(),
            projectSlug: try PrototypeToolSupport.required("projectId", arguments)
        )
        return PrototypeToolSupport.projectSummary(project)
            + "\n" + PrototypeToolSupport.flowSummary(project)
    }
}
