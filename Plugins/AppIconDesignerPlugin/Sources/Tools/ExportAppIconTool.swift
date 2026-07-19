import Foundation
import LumiKernel

public struct ExportAppIconTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "export_app_icon",
        displayName: "Export App Icon",
        description: "Export the current App Icon Designer document or candidate image as an Xcode-ready AppIcon.appiconset."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        [
            "type": "object",
            "properties": [
                "artifactId": [
                    "type": "string",
                    "description": "Optional artifact id. If omitted, the currently selected candidate is exported."
                ],
                "outputDirectory": [
                    "type": "string",
                    "description": "Absolute directory path where AppIcon.appiconset should be created. For Xcode assets, use the .xcassets directory."
                ],
                "setName": [
                    "type": "string",
                    "description": "Optional icon set name. Defaults to AppIcon."
                ],
            ],
            "required": ["outputDirectory"],
        ]
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "Export app icon set"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .medium
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        let language = IconToolSupport.language(context)
        guard let outputDirectory = arguments["outputDirectory"]?.anyValue as? String, !outputDirectory.isEmpty else {
            return IconToolSupport.missingParameter("outputDirectory", language: language)
        }

        let requestedArtifactId = arguments["artifactId"]?.anyValue as? String
        let setName = (arguments["setName"]?.anyValue as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let outputURL = URL(fileURLWithPath: outputDirectory, isDirectory: true)

        do {
            let exportSource = try await MainActor.run {
                let store = AppIconArtifactStore.shared
                if let requestedArtifactId, !requestedArtifactId.isEmpty {
                    guard let artifact = store.artifacts.first(where: { $0.id == requestedArtifactId }) else {
                        throw ExportAppIconToolError.artifactNotFound(requestedArtifactId)
                    }
                    return ExportSource.artifact(artifact)
                }
                if let document = IconDocumentStore.shared.selectedDocument {
                    return ExportSource.document(document)
                }
                if let artifact = store.selectedArtifact {
                    return ExportSource.artifact(artifact)
                }
                throw ExportAppIconToolError.noSelectedSource
            }

            let service = AppIconExportService()
            let result: AppIconExportService.ExportResult
            switch exportSource {
            case .artifact(let artifact):
                result = try service.exportAppIconSet(
                    sourceImagePath: artifact.sourcePath,
                    outputDirectory: outputURL,
                    setName: setName?.isEmpty == false ? setName! : "AppIcon"
                )
            case .document(let document):
                result = try await MainActor.run {
                    try service.exportAppIconSet(
                        document: document,
                        outputDirectory: outputURL,
                        setName: setName?.isEmpty == false ? setName! : "AppIcon"
                    )
                }
            }

            await MainActor.run {
                AppIconArtifactStore.shared.setExportURL(result.appIconSetURL)
                IconDocumentStore.shared.setExportURL(result.appIconSetURL)
            }

            let warningText: String
            if result.lintWarnings.isEmpty {
                warningText = IconToolSupport.localized(language, en: "warnings: none", zh: "警告: 无")
            } else {
                let title = IconToolSupport.localized(language, en: "warnings:", zh: "警告:")
                warningText = title + "\n" + result.lintWarnings.map { "- \($0.message)" }.joined(separator: "\n")
            }

            return IconToolSupport.localized(
                language,
                en: """
                Exported app icon set.
                path: \(result.appIconSetURL.path)
                images: \(result.imageCount)
                \(warningText)
                """,
                zh: """
                已导出 App 图标集。
                路径: \(result.appIconSetURL.path)
                图片数: \(result.imageCount)
                \(warningText)
                """
            )
        } catch {
            await MainActor.run {
                AppIconArtifactStore.shared.setError(error.localizedDescription)
            }
            return IconToolSupport.error(error, language: language)
        }
    }
}

private enum ExportSource {
    case artifact(AppIconArtifact)
    case document(IconDocument)
}

private enum ExportAppIconToolError: LocalizedError {
    case noSelectedSource
    case artifactNotFound(String)

    var errorDescription: String? {
        switch self {
        case .noSelectedSource:
            return "No app icon document or candidate is selected."
        case .artifactNotFound(let id):
            return "App icon artifact not found: \(id)"
        }
    }
}
