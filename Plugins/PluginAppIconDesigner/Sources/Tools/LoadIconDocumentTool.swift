import AgentToolKit
import Foundation

public struct LoadIconDocumentTool: SuperAgentTool {
    public let name = "load_icon_document"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "从 JSON 文件加载一个图标文档，并导入到 App Icon Designer。"
        case .english:
            return "Load an icon document from a JSON file and import it into App Icon Designer."
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "inputPath": ["type": "string", "description": IconToolSupport.description(language, en: "Absolute JSON file path to load.", zh: "要加载的 JSON 文件绝对路径。")],
                "replaceSelected": ["type": "boolean", "description": IconToolSupport.description(language, en: "Replace the selected document instead of importing a new copy.", zh: "替换当前选中文档，而不是导入为新副本。")],
            ],
            "required": ["inputPath"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "Load icon document"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        let language = IconToolSupport.language(arguments)
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
