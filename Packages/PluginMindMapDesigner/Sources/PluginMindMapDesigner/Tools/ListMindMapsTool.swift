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
        let maps = await MainActor.run { MindMapStore.shared.projectMaps }

        if maps.isEmpty {
            return language == .chinese ? "当前项目暂无思维导图。" : "No mind maps in the current project."
        }

        let entries = maps.map { map in
            "- [\(map.id.prefix(8))] \(map.title) (\(map.nodes.count) nodes)"
        }.joined(separator: "\n")

        return language == .chinese
            ? "当前项目共有 \(maps.count) 张思维导图：\n\(entries)"
            : "\(maps.count) mind map(s) in the current project:\n\(entries)"
    }
}
