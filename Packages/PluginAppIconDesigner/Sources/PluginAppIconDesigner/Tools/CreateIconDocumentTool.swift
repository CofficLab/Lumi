import AgentToolKit
import Foundation

public struct CreateIconDocumentTool: SuperAgentTool {
    public let name = "create_icon_document"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "创建一个可编辑的矢量图标文档，后续可以继续设置背景、添加形状、移动图层并导出 SVG。"
        case .english:
            return "Create an editable vector icon document that can be modified with background, shape, layer, and SVG export tools."
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "title": ["type": "string", "description": "Document title."],
                "width": ["type": "number", "description": "Canvas width. Defaults to 1024."],
                "height": ["type": "number", "description": "Canvas height. Defaults to 1024."],
                "background": ["type": "string", "description": "Background color, for example #111827 or #00000000."],
            ],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "Create icon document"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        let title = IconToolSupport.string(arguments, "title")
        let width = IconToolSupport.double(arguments, "width", default: 1024)
        let height = IconToolSupport.double(arguments, "height", default: 1024)
        let background = IconToolSupport.color(arguments, "background", default: "#00000000")

        let document = await MainActor.run {
            IconDocumentStore.shared.createDocument(
                title: title,
                width: width,
                height: height,
                background: background
            )
        }

        return """
        Created icon document.
        documentId: \(document.id)
        title: \(document.title)
        size: \(Int(document.width))x\(Int(document.height))
        """
    }
}
