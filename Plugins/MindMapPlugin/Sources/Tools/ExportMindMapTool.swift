import Foundation
import KernelLumi

/// 导出思维导图为 Markdown 大纲或 JSON 文本。
public struct ExportMindMapTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "export_mind_map",
        displayName: "Export Mind Map",
        description: "Export the current mind map as text. Use format 'markdown' for an indented outline or 'json' for the raw document."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        var properties = MindMapToolSupport.baseProperties()
        properties["format"] = [
            "type": "string",
            "enum": ["markdown", "json"],
            "description": "Export format. Defaults to 'markdown'."
        ]
        return ["type": "object", "properties": .object(properties)]
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        let format = arguments.string("format") ?? "markdown"
        return "Export mind map (\(format))"
    }

    public func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        let language = MindMapToolSupport.language(kernel)
        let (map, scope) = try await MindMapToolSupport.resolveMap(arguments, kernel: kernel)
        let format = arguments.string("format") ?? "markdown"

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
