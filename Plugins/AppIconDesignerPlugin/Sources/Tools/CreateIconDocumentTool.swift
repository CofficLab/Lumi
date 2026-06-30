import Foundation
import LumiCoreKit

public struct CreateIconDocumentTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "create_icon_document",
        displayName: "Create Icon Document",
        description: "Create an editable vector icon document that can be modified with background, shape, layer, and SVG export tools."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
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

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "Create icon document"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        let language = IconToolSupport.language(context)
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

        switch language {
        case .chinese:
            return """
            已创建图标文档。
            文档ID: \(document.id)
            标题: \(document.title)
            尺寸: \(Int(document.width))x\(Int(document.height))
            """
        case .english:
            return """
            Created icon document.
            documentId: \(document.id)
            title: \(document.title)
            size: \(Int(document.width))x\(Int(document.height))
            """
        }
    }
}
