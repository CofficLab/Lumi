import KitAgentTool
import Foundation

public struct CreateIconDocumentTool: SuperAgentTool {
    public let name = "create_icon_document"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Create an editable vector icon document that can be modified with background, shape, layer, and SVG export tools."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        var properties = IconToolSupport.baseProperties(includeDocumentId: false)
        properties["title"] = ["type": "string", "description": "Document title."]
        properties["width"] = ["type": "number", "description": "Canvas width. Defaults to 1024."]
        properties["height"] = ["type": "number", "description": "Canvas height. Defaults to 1024."]
        properties["background"] = ["type": "string", "description": "Background color, for example #111827 or #00000000."]
        return ["type": "object", "properties": properties]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "Create icon document"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let language = IconToolSupport.language
        let scope = try await IconToolSupport.resolveScope(arguments)
        let title = IconToolSupport.string(arguments, "title")
        let width = IconToolSupport.double(arguments, "width", default: 1024)
        let height = IconToolSupport.double(arguments, "height", default: 1024)
        let background = IconToolSupport.color(arguments, "background", default: "#00000000")

        let document = await MainActor.run {
            IconDocumentStore.shared.createDocument(
                title: title,
                width: width,
                height: height,
                background: background,
                scope: scope
            )
        }
        await IconToolSupport.notify(scope: scope, documentId: document.id)

        switch language {
        case .chinese:
            return """
            已创建图标文档。
            作用域: \(scope.rawValue)
            文档ID: \(document.id)
            标题: \(document.title)
            尺寸: \(Int(document.width))x\(Int(document.height))
            """
        case .english:
            return """
            Created icon document.
            scope=\(scope.rawValue)
            documentId: \(document.id)
            title: \(document.title)
            size: \(Int(document.width))x\(Int(document.height))
            """
        }
    }
}
