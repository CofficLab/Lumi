import Foundation
import LumiKernel

public struct ExportAppIconTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "export_app_icon",
        displayName: "Export App Icon",
        description: "Export the current App Icon Designer document or candidate image as an Xcode 26 AppIcon.icon that supports macOS 15 and later."
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
                    "description": "Absolute directory path where AppIcon.icon should be created."
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
        "Export Xcode app icon"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], kernel: LumiKernel) -> LumiCommandRiskLevel {
        .medium
    }

    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        let language = IconToolSupport.language(kernel)
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

            let service = IconComposerExportService()
            let result: IconComposerExportService.ExportResult
            switch exportSource {
            case .artifact(let artifact):
                result = try service.export(
                    sourceImagePath: artifact.sourcePath,
                    outputDirectory: outputURL,
                    name: setName?.isEmpty == false ? setName! : "AppIcon"
                )
            case .document(let document):
                result = try await MainActor.run {
                    try service.export(
                        document: document,
                        outputDirectory: outputURL,
                        name: setName?.isEmpty == false ? setName! : "AppIcon"
                    )
                }
            }

            await MainActor.run {
                AppIconArtifactStore.shared.setExportURL(result.iconURL)
                IconDocumentStore.shared.setExportURL(result.iconURL)
            }

            return IconToolSupport.localized(
                language,
                en: """
                Exported Xcode app icon.
                path: \(result.iconURL.path)
                Add AppIcon.icon to an Xcode 26 project; Xcode generates the macOS 15 fallback automatically.
                """,
                zh: """
                已导出 Xcode App 图标。
                路径: \(result.iconURL.path)
                将 AppIcon.icon 添加到 Xcode 26 项目；Xcode 会自动生成 macOS 15 兼容图标。
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
