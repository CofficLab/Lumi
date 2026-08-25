import KitAgentTool
import Foundation

/// 更新节点文本、备注、颜色或折叠态。
public struct UpdateNodeTool: SuperAgentTool {
    public let name = "update_node"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Update a mind map node's text, note, color, or collapsed state. Only the fields you provide are changed."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        var properties = MindMapToolSupport.baseProperties()
        properties["nodeId"] = ["type": "string", "description": "The node id to update."]
        properties["text"] = ["type": "string", "description": "New node text. Ignored if empty."]
        properties["note"] = ["type": "string", "description": "Optional note attached to the node."]
        properties["color"] = ["type": "string", "description": "Node fill color (hex), e.g. #38bdf8."]
        properties["collapsed"] = ["type": "boolean", "description": "Collapse (true) or expand (false) the node's subtree."]
        return ["type": "object", "properties": properties, "required": ["nodeId"]]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        MindMapToolSupport.localized(MindMapToolSupport.language, en: "Update node", zh: "更新节点")
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let language = MindMapToolSupport.language
        guard let nodeId = MindMapToolSupport.nonEmpty(MindMapToolSupport.string(arguments, "nodeId")) else {
            return MindMapToolSupport.missingParameter("nodeId", language: language)
        }
        let text = MindMapToolSupport.string(arguments, "text")
        let note = MindMapToolSupport.string(arguments, "note")
        let color = MindMapToolSupport.string(arguments, "color")
        let hasCollapsed = arguments["collapsed"]?.value is Bool
        let collapsed = MindMapToolSupport.bool(arguments, "collapsed", default: false)

        // 至少需要提供一个可更新字段。
        guard text != nil || note != nil || color != nil || hasCollapsed else {
            return MindMapToolSupport.localized(
                language,
                en: "Error: Provide at least one of text/note/color/collapsed.",
                zh: "错误：至少提供 text/note/color/collapsed 中的一个。"
            )
        }

        do {
            let (map, scope) = try await MindMapToolSupport.resolveMap(arguments)
            let updated = try await MainActor.run {
                try MindMapStore.shared.updateNode(
                    mapId: map.id, nodeId: nodeId, scope: scope,
                    text: text, note: note, color: color, collapsed: hasCollapsed ? collapsed : nil
                )
            }
            await MindMapToolSupport.notify(scope: scope, mapId: map.id)
            switch language {
            case .chinese:
                return "已更新节点 \(nodeId.prefix(8))。\n作用域: \(scope.rawValue)\n思维导图ID: \(updated.id)"
            case .english:
                return "Updated node \(nodeId.prefix(8)).\nscope=\(scope.rawValue)\nmapId: \(updated.id)"
            }
        } catch {
            await MainActor.run { MindMapStore.shared.setError(error.localizedDescription) }
            return MindMapToolSupport.error(error, language: language)
        }
    }
}
