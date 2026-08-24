import Foundation
import KernelLumi

/// 按 id 加载思维导图到画布并选中。
public struct LoadMindMapTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "load_mind_map",
        displayName: "Load Mind Map",
        description: "Load (select) a mind map by id so it shows on the canvas. Use list_mind_maps to discover ids."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        var properties = MindMapToolSupport.baseProperties(includeScope: true, includeMapId: false)
        properties["mapId"] = ["type": "string", "description": "The mind map id to load."]
        return ["type": "object", "properties": .object(properties), "required": ["mapId"]]
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "Load mind map"
    }

    public func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        let language = MindMapToolSupport.language(kernel)
        guard let mapId = MindMapToolSupport.nonEmpty(arguments.string("mapId")) else {
            return MindMapToolSupport.missingParameter("mapId", language: language)
        }

        let scope = try await MindMapToolSupport.resolveScope(arguments, kernel: kernel)
        do {
            try await MainActor.run {
                // 先确保该作用域磁盘数据已载入，再选中。
                MindMapStore.shared.reload(scope: scope)
                try MindMapStore.shared.selectMindMap(id: mapId, scope: scope)
            }
            await MindMapToolSupport.notify(scope: scope, mapId: mapId)
            let map = await MainActor.run { MindMapStore.shared.maps(for: scope).first { $0.id == mapId } }
            switch language {
            case .chinese:
                return "已加载思维导图到画布。\n作用域: \(scope.rawValue)\n思维导图ID: \(mapId)\n标题: \(map?.title ?? "?")\n节点数: \(map?.nodes.count ?? 0)"
            case .english:
                return "Loaded mind map onto canvas.\nscope=\(scope.rawValue)\nmapId: \(mapId)\ntitle: \(map?.title ?? "?")\nnodes: \(map?.nodes.count ?? 0)"
            }
        } catch {
            await MainActor.run { MindMapStore.shared.setError(error.localizedDescription) }
            return MindMapToolSupport.error(error, language: language)
        }
    }
}
