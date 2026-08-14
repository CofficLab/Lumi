import Foundation
import KernelLumi

/// 把节点（含子树）重新挂到新的父节点下。
public struct MoveNodeTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "move_node",
        displayName: "Move Node",
        description: "Reattach a node (with its subtree) under a new parent. Rejects moves that would create a cycle."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        var properties = MindMapToolSupport.baseProperties()
        properties["nodeId"] = ["type": "string", "description": "The node id to move."]
        properties["toParentId"] = ["type": "string", "description": "The new parent node id."]
        return ["type": "object", "properties": .object(properties), "required": ["nodeId", "toParentId"]]
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "Move node"
    }

    public func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        let language = MindMapToolSupport.language(kernel)
        guard let nodeId = MindMapToolSupport.nonEmpty(arguments.string("nodeId")) else {
            return MindMapToolSupport.missingParameter("nodeId", language: language)
        }
        guard let toParentId = MindMapToolSupport.nonEmpty(arguments.string("toParentId")) else {
            return MindMapToolSupport.missingParameter("toParentId", language: language)
        }

        do {
            let (map, scope) = try await MindMapToolSupport.resolveMap(arguments, kernel: kernel)
            let updated = try await MainActor.run {
                try MindMapStore.shared.moveNode(mapId: map.id, nodeId: nodeId, toParentId: toParentId, scope: scope)
            }
            await MindMapToolSupport.notify(scope: scope, mapId: map.id)
            switch language {
            case .chinese:
                return "已移动节点 \(nodeId.prefix(8)) 到父节点 \(toParentId.prefix(8)) 下。\n作用域: \(scope.rawValue)\n思维导图ID: \(updated.id)"
            case .english:
                return "Moved node \(nodeId.prefix(8)) under parent \(toParentId.prefix(8)).\nscope=\(scope.rawValue)\nmapId: \(updated.id)"
            }
        } catch {
            await MainActor.run { MindMapStore.shared.setError(error.localizedDescription) }
            return MindMapToolSupport.error(error, language: language)
        }
    }
}
