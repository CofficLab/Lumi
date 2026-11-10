import Foundation
import KitAgentTool

/// 列出当前项目内的全部思维导图。
public struct ListMindMapsTool: SuperAgentTool {
    public let name = "list_mind_maps"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "List all mind maps in the current project. Returns id, title, node count and updatedAt for each."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        ["type": "object", "properties": [:]]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        MindMapToolSupport.localized(MindMapToolSupport.language, en: "List mind maps", zh: "列出思维导图")
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .safe
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let language = MindMapToolSupport.language
        // 列表必须反映磁盘上的真实状态：缓存的 store 可能还持有
        // 别的入口（画布或另一个会话）新建导图之前的旧快照。
        let maps = await MainActor.run {
            let store = MindMapToolSupport.store()
            store.reload()
            return store.projectMaps
        }

        if maps.isEmpty {
            return language == .chinese ? "当前项目暂无思维导图。" : "No mind maps in the current project."
        }

        // 必须返回完整 ID：load / 编辑 / 导出工具都按完整 ID 精确匹配，
        // 截断后 Agent 无法完成列表发现 → 加载的工作流（#1001）。
        let entries = maps.map { map in
            "- [\(map.id)] \(map.title) (\(map.nodes.count) nodes)"
        }.joined(separator: "\n")

        return language == .chinese
            ? "当前项目共有 \(maps.count) 张思维导图：\n\(entries)"
            : "\(maps.count) mind map(s) in the current project:\n\(entries)"
    }
}
