import Foundation
import KernelLumi

/// 给指定父节点批量添加子节点（AI 扩展思维导图的核心工具）。
public struct AddChildNodeTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "add_child_node",
        displayName: "Add Child Node",
        description: "Add one or more child nodes under a parent node in the current mind map. Pass multiple texts to add several siblings at once. The canvas re-layouts automatically."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        var properties = MindMapToolSupport.baseProperties()
        properties["parentId"] = ["type": "string", "description": "The parent node id. Use the root id to create top-level branches."]
        properties["texts"] = [
            "type": "array",
            "items": ["type": "string"],
            "description": "One or more child node texts. Each becomes a new sibling under parentId."
        ]
        properties["color"] = ["type": "string", "description": "Optional node fill color (hex), e.g. #38bdf8."]
        return ["type": "object", "properties": .object(properties), "required": ["parentId", "texts"]]
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        let count = arguments.stringArray("texts")?.count ?? 1
        return "Add \(count) child node\(count == 1 ? "" : "s")"
    }

    public func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        let language = MindMapToolSupport.language(kernel)
        guard let parentId = MindMapToolSupport.nonEmpty(arguments.string("parentId")) else {
            return MindMapToolSupport.missingParameter("parentId", language: language)
        }
        let texts = arguments.stringArray("texts") ?? []
        let nonEmptyTexts = texts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !nonEmptyTexts.isEmpty else {
            return MindMapToolSupport.missingParameter("texts", language: language)
        }
        let color = arguments.string("color")

        do {
            let (map, scope) = try await MindMapToolSupport.resolveMap(arguments, kernel: kernel)
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
