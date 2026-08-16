import AgentToolKit
import Foundation

public struct LoadIconDocumentTool: SuperAgentTool {
    public let name = "load_icon_document"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Load an icon document from a JSON file and import it into App Icon Designer."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        var properties = IconToolSupport.baseProperties()
        properties["inputPath"] = ["type": "string", "description": "Absolute JSON file path to load."]
        properties["replaceSelected"] = ["type": "boolean", "description": "Replace the selected document instead of importing a new copy."]
        return ["type": "object", "properties": properties, "required": ["inputPath"]]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "Load icon document"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let language = IconToolSupport.language
        guard let inputPath = IconToolSupport.string(arguments, "inputPath"), !inputPath.isEmpty else {
            return IconToolSupport.missingParameter("inputPath", language: language)
        }

        do {
            let inputURL = URL(fileURLWithPath: inputPath)
            let loadedDocument = try IconDocumentFileService().load(from: inputURL)
            let replaceSelected = IconToolSupport.bool(arguments, "replaceSelected", default: false)
            let scope = try await IconToolSupport.resolveScope(arguments)

            let document = try await MainActor.run {
                if replaceSelected {
                    return try IconDocumentStore.shared.replaceDocument(loadedDocument, scope: scope)
                }
                return IconDocumentStore.shared.importDocument(loadedDocument, scope: scope)
            }
            await IconToolSupport.notify(scope: scope, documentId: document.id)

            return IconToolSupport.localized(
                language,
                en: """
                Loaded icon document.
                scope=\(scope.rawValue)
                documentId: \(document.id)
                title: \(document.title)
                layerCount: \(document.layers.count)
                """,
                zh: """
                已加载图标文档。
                作用域: \(scope.rawValue)
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
