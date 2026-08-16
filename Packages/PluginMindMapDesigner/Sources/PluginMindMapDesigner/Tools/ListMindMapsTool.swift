import AgentToolKit
import Foundation

/// 列出指定作用域下的全部思维导图。
public struct ListMindMapsTool: SuperAgentTool {
    public let name = "list_mind_maps"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "List all mind maps in a storage scope (project or app). Returns id, title, node count and updatedAt for each."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        var properties = MindMapToolSupport.baseProperties(includeMapId: false)
        properties["includeBothScopes"] = ["type": "boolean", "description": "If true, list both scopes regardless of `scope`."]
        return ["type": "object", "properties": properties]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        MindMapToolSupport.localized(MindMapToolSupport.language, en: "List mind maps", zh: "列出思维导图")
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .safe
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let language = MindMapToolSupport.language
        let includeBoth = MindMapToolSupport.bool(arguments, "includeBothScopes")

        if includeBoth {
            let (project, app) = await MainActor.run {
                (MindMapStore.shared.maps(for: .project), MindMapStore.shared.maps(for: .app))
            }
            return formatTwoScopes(project: project, app: app, language: language)
        }

        let scope = try await MindMapToolSupport.resolveScope(arguments)
        let maps = await MainActor.run { MindMapStore.shared.maps(for: scope) }
        return formatSingleScope(scope: scope, maps: maps, language: language)
    }

    private func formatSingleScope(scope: MindMapScope, maps: [MindMap], language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            if maps.isEmpty { return "作用域 \(scope.rawValue) 下暂无思维导图。" }
            return "作用域 \(scope.rawValue) 下共 \(maps.count) 张：\n" + maps.map { entry($0) }.joined(separator: "\n")
        case .english:
            if maps.isEmpty { return "No mind maps in scope \(scope.rawValue)." }
            return "\(maps.count) mind map(s) in scope \(scope.rawValue):\n" + maps.map { entry($0) }.joined(separator: "\n")
        }
    }

    private func formatTwoScopes(project: [MindMap], app: [MindMap], language: LanguagePreference) -> String {
        let p = formatSingleScope(scope: .project, maps: project, language: language)
        let a = formatSingleScope(scope: .app, maps: app, language: language)
        return "\(p)\n\n\(a)"
    }

    private func entry(_ map: MindMap) -> String {
        "- [\(map.id.prefix(8))] \(map.title) (\(map.nodes.count) nodes)"
    }
}
