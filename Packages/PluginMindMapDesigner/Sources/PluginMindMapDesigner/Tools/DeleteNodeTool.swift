import AgentToolKit
import Foundation

/// 删除节点及其整个子树（根节点不可删除）。
public struct DeleteNodeTool: SuperAgentTool {
    public let name = "delete_node"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Delete a node and its entire subtree from the mind map. The root node cannot be deleted."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        var properties = MindMapToolSupport.baseProperties()
        properties["nodeId"] = ["type": "string", "description": "The node id to delete (its descendants are removed too)."]
        return ["type": "object", "properties": properties, "required": ["nodeId"]]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        MindMapToolSupport.localized(MindMapToolSupport.language, en: "Delete node", zh: "删除节点")
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let language = MindMapToolSupport.language
        guard let nodeId = MindMapToolSupport.nonEmpty(MindMapToolSupport.string(arguments, "nodeId")) else {
            return MindMapToolSupport.missingParameter("nodeId", language: language)
        }

        do {
            let (map, scope) = try await MindMapToolSupport.resolveMap(arguments)
            let removedCount = map.descendantIds(of: nodeId).count + 1
            let updated = try await MainActor.run {
                try MindMapStore.shared.deleteNode(mapId: map.id, nodeId: nodeId, scope: scope)
            }
            await MindMapToolSupport.notify(scope: scope, mapId: map.id)
            switch language {
            case .chinese:
                return "已删除节点 \(nodeId.prefix(8)) 及其 \(removedCount - 1) 个后代。\n作用域: \(scope.rawValue)\n思维导图ID: \(updated.id)\n剩余节点数: \(updated.nodes.count)"
            case .english:
                return "Deleted node \(nodeId.prefix(8)) and \(removedCount - 1) descendant(s).\nscope=\(scope.rawValue)\nmapId: \(updated.id)\nremainingNodes: \(updated.nodes.count)"
            }
        } catch {
            await MainActor.run { MindMapStore.shared.setError(error.localizedDescription) }
            return MindMapToolSupport.error(error, language: language)
        }
    }
}
