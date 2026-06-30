import Foundation
import LumiCoreKit

public struct ExportIconSVGTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "export_icon_svg",
        displayName: "Export Icon Svg",
        description: "Export the current editable icon document as an SVG file."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        [
            "type": "object",
            "properties": [
                "outputPath": ["type": "string", "description": "Absolute SVG output path. If omitted, a file is written to the temporary directory."],
            ],
        ]
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "Export icon SVG"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .medium
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        let language = IconToolSupport.language(context)
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

    private func outputURL(arguments: [String: LumiJSONValue], document: IconDocument) -> URL {
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
