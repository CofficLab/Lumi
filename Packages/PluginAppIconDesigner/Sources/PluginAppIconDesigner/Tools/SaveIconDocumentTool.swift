import AgentToolKit
import Foundation

public struct SaveIconDocumentTool: SuperAgentTool {
    public let name = "save_icon_document"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Save the current editable icon document as a JSON file."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        var properties = IconToolSupport.baseProperties()
        properties["outputPath"] = ["type": "string", "description": "Absolute JSON output path. If omitted, a file is written to the temporary directory."]
        return ["type": "object", "properties": properties]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "Save icon document"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let language = IconToolSupport.language
        do {
            let (document, _) = try await IconToolSupport.resolveDocument(arguments)

            let outputURL = outputURL(arguments: arguments, document: document)
            try FileManager.default.createDirectory(
                at: outputURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try IconDocumentFileService().save(document: document, to: outputURL)

            await MainActor.run {
                IconDocumentStore.shared.setExportURL(outputURL)
            }

            return IconToolSupport.localized(
                language,
                en: """
                Saved icon document.
                documentId: \(document.id)
                path: \(outputURL.path)
                """,
                zh: """
                已保存图标文档。
                文档ID: \(document.id)
                路径: \(outputURL.path)
                """
            )
        } catch {
            await MainActor.run {
                IconDocumentStore.shared.setError(error.localizedDescription)
            }
            return IconToolSupport.error(error, language: language)
        }
    }

    private func outputURL(arguments: [String: ToolArgument], document: IconDocument) -> URL {
        if let outputPath = IconToolSupport.string(arguments, "outputPath"), !outputPath.isEmpty {
            return URL(fileURLWithPath: outputPath)
        }

        let safeTitle = document.title
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9_-]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let fileName = (safeTitle.isEmpty ? "icon" : safeTitle) + "-\(document.id.prefix(8)).json"
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiAppIconDesigner", isDirectory: true)
            .appendingPathComponent(fileName)
    }
}
