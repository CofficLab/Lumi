import Foundation
import LumiKernel

public struct LoadIconDocumentTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "load_icon_document",
        displayName: "Load Icon Document",
        description: "Load an icon document from a JSON file and import it into App Icon Designer."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        [
            "type": "object",
            "properties": [
                "inputPath": ["type": "string", "description": "Absolute JSON file path to load."],
                "replaceSelected": ["type": "boolean", "description": "Replace the selected document instead of importing a new copy."],
            ],
            "required": ["inputPath"],
        ]
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "Load icon document"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .medium
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        let language = IconToolSupport.language(context)
        guard let inputPath = IconToolSupport.string(arguments, "inputPath"), !inputPath.isEmpty else {
            return IconToolSupport.missingParameter("inputPath", language: language)
        }

        do {
            let inputURL = URL(fileURLWithPath: inputPath)
            let loadedDocument = try IconDocumentFileService().load(from: inputURL)
            let replaceSelected = IconToolSupport.bool(arguments, "replaceSelected", default: false)

            let document = try await MainActor.run {
                if replaceSelected {
                    return try IconDocumentStore.shared.replaceSelectedDocument(loadedDocument)
                }
                return IconDocumentStore.shared.importDocument(loadedDocument)
            }

            return IconToolSupport.localized(
                language,
                en: """
                Loaded icon document.
                documentId: \(document.id)
                title: \(document.title)
                layerCount: \(document.layers.count)
                """,
                zh: """
                已加载图标文档。
                文档ID: \(document.id)
                标题: \(document.title)
                图层数: \(document.layers.count)
                """
            )
        } catch {
            await MainActor.run {
                IconDocumentStore.shared.setError(error.localizedDescription)
            }
            return IconToolSupport.error(error, language: language)
        }
    }
}
