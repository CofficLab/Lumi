import AgentToolKit
import Foundation

/// 给指定父节点批量添加子节点（AI 扩展思维导图的核心工具）。
public struct AddChildNodeTool: SuperAgentTool {
    public let name = "add_child_node"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Add one or more child nodes under a parent node in the current mind map. Pass multiple texts to add several siblings at once. The canvas re-layouts automatically."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        var properties = MindMapToolSupport.baseProperties()
        properties["parentId"] = ["type": "string", "description": "The parent node id. Use the root id to create top-level branches."]
        properties["texts"] = [
            "type": "array",
            "items": ["type": "string"],
            "description": "One or more child node texts. Each becomes a new sibling under parentId."
        ]
        properties["color"] = ["type": "string", "description": "Optional node fill color (hex), e.g. #38bdf8."]
        return ["type": "object", "properties": properties, "required": ["parentId", "texts"]]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        let count = MindMapToolSupport.stringArray(arguments, "texts")?.count ?? 1
        let label = count == 1
            ? MindMapToolSupport.localized(MindMapToolSupport.language, en: "Add child node", zh: "添加子节点")
            : MindMapToolSupport.localized(MindMapToolSupport.language, en: "Add \(count) child nodes", zh: "添加 \(count) 个子节点")
        return label
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let language = MindMapToolSupport.language
        guard let parentId = MindMapToolSupport.nonEmpty(MindMapToolSupport.string(arguments, "parentId")) else {
            return MindMapToolSupport.missingParameter("parentId", language: language)
        }
        let texts = MindMapToolSupport.stringArray(arguments, "texts") ?? []
        let nonEmptyTexts = texts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !nonEmptyTexts.isEmpty else {
            return MindMapToolSupport.missingParameter("texts", language: language)
        }
        let color = MindMapToolSupport.string(arguments, "color")

        do {
            let (map, scope) = try await MindMapToolSupport.resolveMap(arguments)
            let (_, created) = try await MainActor.run {
                try MindMapStore.shared.addChildNodes(mapId: map.id, parentId: parentId, texts: nonEmptyTexts, color: color, scope: scope)
            }
            await MindMapToolSupport.notify(scope: scope, mapId: map.id)

            switch language {
            case .chinese:
                return """
                已添加 \(created.count) 个子节点到父节点 \(parentId.prefix(8))。
                作用域: \(scope.rawValue)
                思维导图ID: \(map.id)
                新节点:
                \(created.map { MindMapToolSupport.nodeSummary($0, language: language) }.joined(separator: "\n"))
                总节点数: \(map.nodes.count + created.count)
                """
            case .english:
                return """
                Added \(created.count) child node(s) under parent \(parentId.prefix(8)).
                scope=\(scope.rawValue)
                mapId: \(map.id)
                new nodes:
                \(created.map { MindMapToolSupport.nodeSummary($0, language: language) }.joined(separator: "\n"))
                totalNodes: \(map.nodes.count + created.count)
                """
            }
        } catch {
            await MainActor.run { MindMapStore.shared.setError(error.localizedDescription) }
            return MindMapToolSupport.error(error, language: language)
        }
    }
}
