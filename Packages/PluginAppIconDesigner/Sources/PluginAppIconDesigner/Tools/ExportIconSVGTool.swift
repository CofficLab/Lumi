import AgentToolKit
import Foundation

public struct ExportIconSVGTool: SuperAgentTool {
    public let name = "export_icon_svg"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "把当前可编辑图标文档导出为 SVG 文件。"
        case .english:
            return "Export the current editable icon document as an SVG file."
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "outputPath": ["type": "string", "description": "Absolute SVG output path. If omitted, a file is written to the temporary directory."],
            ],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "Export icon SVG"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        do {
            let document = try await MainActor.run {
                guard let document = IconDocumentStore.shared.selectedDocument else {
                    throw IconDocumentStoreError.noSelectedDocument
                }
                return document
            }

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

            return """
            Exported icon SVG.
            documentId: \(document.id)
            path: \(outputURL.path)
            """
        } catch {
            await MainActor.run {
                IconDocumentStore.shared.setError(error.localizedDescription)
            }
            return "Error: \(error.localizedDescription)"
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
