import KitAgentTool
import Foundation

public struct ExportIconSVGTool: SuperAgentTool {
    public let name = "export_icon_svg"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Export the current editable icon document as an SVG file."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        var properties = IconToolSupport.baseProperties()
        properties["outputPath"] = ["type": "string", "description": "Absolute SVG output path. If omitted, a file is written to the temporary directory."]
        return ["type": "object", "properties": properties]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "Export icon SVG"
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

            let svg = IconSVGRenderer().render(document: document)
            try svg.write(to: outputURL, atomically: true, encoding: .utf8)

            await MainActor.run {
                IconDocumentStore.shared.setExportURL(outputURL)
            }

            return IconToolSupport.localized(
                language,
                en: """
                Exported icon SVG.
                documentId: \(document.id)
                path: \(outputURL.path)
                """,
                zh: """
                已导出图标 SVG。
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
        let fileName = (safeTitle.isEmpty ? "icon" : safeTitle) + "-\(document.id.prefix(8)).svg"
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiAppIconDesigner", isDirectory: true)
            .appendingPathComponent(fileName)
    }
}
