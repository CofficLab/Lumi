import KitAgentTool
import Foundation

/// 导出思维导图为 Markdown 大纲或 JSON 文本。
public struct ExportMindMapTool: SuperAgentTool {
    public let name = "export_mind_map"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Export the current mind map as text. Use format 'markdown' for an indented outline or 'json' for the raw document."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        var properties = MindMapToolSupport.baseProperties()
        properties["format"] = [
            "type": "string",
            "enum": ["markdown", "json"],
            "description": "Export format. Defaults to 'markdown'."
        ]
        return ["type": "object", "properties": properties]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        let format = MindMapToolSupport.string(arguments, "format") ?? "markdown"
        let label = MindMapToolSupport.localized(MindMapToolSupport.language, en: "Export mind map", zh: "导出思维导图")
        return "\(label) (\(format))"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .safe
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let language = MindMapToolSupport.language
        let (map, scope) = try await MindMapToolSupport.resolveMap(arguments)
        let format = MindMapToolSupport.string(arguments, "format") ?? "markdown"

        let payload: String
        switch format.lowercased() {
        case "json":
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = (try? encoder.encode(map)) ?? Data()
            payload = String(data: data, encoding: .utf8) ?? "{}"
        default:
            payload = MindMapMarkdownCodec.encode(map)
        }

        switch language {
        case .chinese:
            return """
            已导出思维导图（\(format)）。
            作用域: \(scope.rawValue)
            思维导图ID: \(map.id)
            ----
            \(payload)
            """
        case .english:
            return """
            Exported mind map (\(format)).
            scope=\(scope.rawValue)
            mapId: \(map.id)
            ----
            \(payload)
            """
        }
    }
}
