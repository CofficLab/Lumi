import Foundation
import KernelLumi

/// 从 Markdown 大纲文本创建一张新的思维导图。
public struct ImportOutlineTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "import_outline",
        displayName: "Import Outline",
        description: "Create a new mind map from an indented Markdown outline. The first line becomes the root; nested '- ' list items become child nodes by indentation."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        var properties = MindMapToolSupport.baseProperties(includeMapId: false)
        properties["outline"] = [
            "type": "string",
            "description": "Markdown outline. Example:\n# Topic\n- Branch A\n  - Sub A1\n- Branch B"
        ]
        properties["title"] = ["type": "string", "description": "Optional map title. Defaults to the outline's first heading."]
        properties["layoutDirection"] = [
            "type": "string",
            "enum": .array(MindMapLayoutDirection.allCases.map { .string($0.rawValue) }),
            "description": "Layout direction. Defaults to 'bilateral'."
        ]
        return ["type": "object", "properties": .object(properties), "required": ["outline"]]
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "Import outline"
    }

    public func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        let language = MindMapToolSupport.language(kernel)
        guard let outline = MindMapToolSupport.nonEmpty(arguments.string("outline")) else {
            return MindMapToolSupport.missingParameter("outline", language: language)
        }

        let scope = try await MindMapToolSupport.resolveScope(arguments, kernel: kernel)
        let title = arguments.string("title")
        let direction: MindMapLayoutDirection = {
            if let raw = arguments.string("layoutDirection"), let parsed = MindMapLayoutDirection(rawValue: raw) {
                return parsed
            }
            return .bilateral
        }()

        let map = await MainActor.run {
            MindMapStore.shared.importFromMarkdown(markdown: outline, title: title, direction: direction, scope: scope)
        }
        await MindMapToolSupport.notify(scope: scope, mapId: map.id)

        switch language {
        case .chinese:
            return """
            已从大纲导入并创建思维导图。
            作用域: \(scope.rawValue)
            思维导图ID: \(map.id)
            标题: \(map.title)
            节点数: \(map.nodes.count)
            """
        case .english:
            return """
            Imported outline into a new mind map.
            scope=\(scope.rawValue)
            mapId: \(map.id)
            title: \(map.title)
            nodes: \(map.nodes.count)
            """
        }
    }
}
