import Foundation
import KernelLumi

/// 显式保存思维导图到磁盘并刷新画布。
public struct SaveMindMapTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "save_mind_map",
        displayName: "Save Mind Map",
        description: "Persist the current mind map to disk and refresh the canvas. Edits are auto-saved, so this mainly confirms and reloads."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        ["type": "object", "properties": .object(MindMapToolSupport.baseProperties())]
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "Save mind map"
    }

    public func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        let language = MindMapToolSupport.language(kernel)
        let (map, scope) = try await MindMapToolSupport.resolveMap(arguments, kernel: kernel)
        await MindMapToolSupport.notify(scope: scope, mapId: map.id)
        switch language {
        case .chinese:
            return "已保存思维导图。\n作用域: \(scope.rawValue)\n思维导图ID: \(map.id)\n标题: \(map.title)\n节点数: \(map.nodes.count)"
        case .english:
            return "Saved mind map.\nscope=\(scope.rawValue)\nmapId: \(map.id)\ntitle: \(map.title)\nnodes: \(map.nodes.count)"
        }
    }
}
