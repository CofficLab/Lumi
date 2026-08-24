import Foundation
import KernelLumi

/// 更新节点文本、备注、颜色或折叠态。
public struct UpdateNodeTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "update_node",
        displayName: "Update Node",
        description: "Update a mind map node's text, note, color, or collapsed state. Only the fields you provide are changed."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        var properties = MindMapToolSupport.baseProperties()
        properties["nodeId"] = ["type": "string", "description": "The node id to update."]
        properties["text"] = ["type": "string", "description": "New node text. Ignored if empty."]
        properties["note"] = ["type": "string", "description": "Optional note attached to the node."]
        properties["color"] = ["type": "string", "description": "Node fill color (hex), e.g. #38bdf8."]
        properties["collapsed"] = ["type": "boolean", "description": "Collapse (true) or expand (false) the node's subtree."]
        return ["type": "object", "properties": .object(properties), "required": ["nodeId"]]
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "Update node"
    }

    public func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        let language = MindMapToolSupport.language(kernel)
        guard let nodeId = MindMapToolSupport.nonEmpty(arguments.string("nodeId")) else {
            return MindMapToolSupport.missingParameter("nodeId", language: language)
        }
        let text = arguments.string("text")
        let note = arguments.string("note")
        let color = arguments.string("color")
        let collapsed = arguments.bool("collapsed")

        // 至少需要提供一个可更新字段。
        guard text != nil || note != nil || color != nil || collapsed != nil else {
            return MindMapToolSupport.localized(
                language,
                en: "Error: Provide at least one of text/note/color/collapsed.",
                zh: "错误：至少提供 text/note/color/collapsed 中的一个。"
            )
        }

        do {
            let (map, scope) = try await MindMapToolSupport.resolveMap(arguments, kernel: kernel)
            let updated = try await MainActor.run {
                try MindMapStore.shared.updateNode(
                    mapId: map.id, nodeId: nodeId, scope: scope,
                    text: text, note: note, color: color, collapsed: collapsed
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
