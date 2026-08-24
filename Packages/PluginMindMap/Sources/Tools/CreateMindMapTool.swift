import Foundation
import KernelLumi

/// 新建一张思维导图（含根节点文本、标题、布局方向）。
public struct CreateMindMapTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "create_mind_map",
        displayName: "Create Mind Map",
        description: "Create a new mind map with a root node. The root text usually represents the central topic. Returns the new map id."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        var properties = MindMapToolSupport.baseProperties(includeMapId: false)
        properties["rootText"] = ["type": "string", "description": "Text of the root (central) node."]
        properties["title"] = ["type": "string", "description": "Optional map title. Defaults to rootText."]
        properties["layoutDirection"] = [
            "type": "string",
            "enum": .array(MindMapLayoutDirection.allCases.map { .string($0.rawValue) }),
            "description": "Layout direction. Defaults to 'bilateral' (root centered, branches left/right)."
        ]
        return ["type": "object", "properties": .object(properties), "required": ["rootText"]]
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "Create mind map"
    }

    public func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        let language = MindMapToolSupport.language(kernel)
        guard let rootText = MindMapToolSupport.nonEmpty(arguments.string("rootText")) else {
            return MindMapToolSupport.missingParameter("rootText", language: language)
        }

        let scope = try await MindMapToolSupport.resolveScope(arguments, kernel: kernel)
        let title = arguments.string("title")
        let direction: MindMapLayoutDirection = {
            if let raw = arguments.string("layoutDirection"), let parsed = MindMapLayoutDirection(rawValue: raw) {
                return parsed
            }
            return .bilateral
        }()

        let map = await MainActor.run {
            MindMapStore.shared.createMindMap(title: title, rootText: rootText, direction: direction, scope: scope)
        }
        await MindMapToolSupport.notify(scope: scope, mapId: map.id)

        switch language {
        case .chinese:
            return """
            已创建思维导图。
            作用域: \(scope.rawValue)
            思维导图ID: \(map.id)
            标题: \(map.title)
            布局: \(map.layoutDirection.rawValue)
            根节点ID: \(map.root?.id ?? "")
            接下来用 add_child_node 给根节点添加分支。
            """
        case .english:
            return """
            Created mind map.
            scope=\(scope.rawValue)
            mapId: \(map.id)
            title: \(map.title)
            layout: \(map.layoutDirection.rawValue)
            rootId: \(map.root?.id ?? "")
            Next, use add_child_node to add branches under the root.
            """
        }
    }
}
