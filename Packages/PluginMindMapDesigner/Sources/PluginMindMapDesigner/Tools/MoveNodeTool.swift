import AgentToolKit
import Foundation

/// 把节点（含子树）重新挂到新的父节点下。
public struct MoveNodeTool: SuperAgentTool {
    public let name = "move_node"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Reattach a node (with its subtree) under a new parent. Rejects moves that would create a cycle."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        var properties = MindMapToolSupport.baseProperties()
        properties["nodeId"] = ["type": "string", "description": "The node id to move."]
        properties["toParentId"] = ["type": "string", "description": "The new parent node id."]
        return ["type": "object", "properties": properties, "required": ["nodeId", "toParentId"]]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        MindMapToolSupport.localized(MindMapToolSupport.language, en: "Move node", zh: "移动节点")
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let language = MindMapToolSupport.language
        guard let nodeId = MindMapToolSupport.nonEmpty(MindMapToolSupport.string(arguments, "nodeId")) else {
            return MindMapToolSupport.missingParameter("nodeId", language: language)
        }
        guard let toParentId = MindMapToolSupport.nonEmpty(MindMapToolSupport.string(arguments, "toParentId")) else {
            return MindMapToolSupport.missingParameter("toParentId", language: language)
        }

        do {
            let (map, scope) = try await MindMapToolSupport.resolveMap(arguments)
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
