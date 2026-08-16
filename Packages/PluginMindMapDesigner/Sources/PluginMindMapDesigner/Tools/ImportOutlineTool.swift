import AgentToolKit
import Foundation

/// 从 Markdown 大纲文本创建一张新的思维导图。
public struct ImportOutlineTool: SuperAgentTool {
    public let name = "import_outline"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Create a new mind map from an indented Markdown outline. The first line becomes the root; nested '- ' list items become child nodes by indentation."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        var properties = MindMapToolSupport.baseProperties(includeMapId: false)
        properties["outline"] = [
            "type": "string",
            "description": "Markdown outline. Example:\n# Topic\n- Branch A\n  - Sub A1\n- Branch B"
        ]
        properties["title"] = ["type": "string", "description": "Optional map title. Defaults to the outline's first heading."]
        properties["layoutDirection"] = [
            "type": "string",
            "enum": MindMapLayoutDirection.allCases.map(\.rawValue),
            "description": "Layout direction. Defaults to 'bilateral'."
        ]
        return ["type": "object", "properties": properties, "required": ["outline"]]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        MindMapToolSupport.localized(MindMapToolSupport.language, en: "Import outline", zh: "导入大纲")
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let language = MindMapToolSupport.language
        guard let outline = MindMapToolSupport.nonEmpty(MindMapToolSupport.string(arguments, "outline")) else {
            return MindMapToolSupport.missingParameter("outline", language: language)
        }

        let scope = try await MindMapToolSupport.resolveScope(arguments)
        let title = MindMapToolSupport.string(arguments, "title")
        let direction: MindMapLayoutDirection = {
            if let raw = MindMapToolSupport.string(arguments, "layoutDirection"), let parsed = MindMapLayoutDirection(rawValue: raw) {
                return parsed
            }
            return .bilateral
        }()

        let map = await MainActor.run {
            MindMapStore.shared.importFromMarkdown(markdown: outline, title: title, direction: direction, scope: scope)
        }
        await MindMapToolSupport.notify(scope: scope, mapId: map.id)

        switch language {
        case .chinese:
            return """
            已从大纲导入并创建思维导图。
            作用域: \(scope.rawValue)
            思维导图ID: \(map.id)
            标题: \(map.title)
            节点数: \(map.nodes.count)
            """
        case .english:
            return """
            Imported outline into a new mind map.
            scope=\(scope.rawValue)
            mapId: \(map.id)
            title: \(map.title)
            nodes: \(map.nodes.count)
            """
        }
    }
}
