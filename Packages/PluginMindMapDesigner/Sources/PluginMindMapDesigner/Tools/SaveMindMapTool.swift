import KitAgentTool
import Foundation

/// 显式保存思维导图到磁盘并刷新画布。
public struct SaveMindMapTool: SuperAgentTool {
    public let name = "save_mind_map"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Persist the current mind map to disk, recreating a missing file if needed, and refresh the canvas."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        ["type": "object", "properties": MindMapToolSupport.baseProperties()]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        MindMapToolSupport.localized(MindMapToolSupport.language, en: "Save mind map", zh: "保存思维导图")
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .safe
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let language = MindMapToolSupport.language
        // 显式保存落盘的是内存中的当前状态，不能先 reload 把缺失文件的地图抹掉。
        let (map, scope) = try await MindMapToolSupport.resolveMap(arguments, reloadingDisk: false)
        try await MindMapToolSupport.save(map, scope: scope)
        await MindMapToolSupport.notify(scope: scope, mapId: map.id)
        switch language {
        case .chinese:
            return "已保存思维导图。\n思维导图ID: \(map.id)\n标题: \(map.title)\n节点数: \(map.nodes.count)"
        case .english:
            return "Saved mind map.\nmapId: \(map.id)\ntitle: \(map.title)\nnodes: \(map.nodes.count)"
        }
    }
}
