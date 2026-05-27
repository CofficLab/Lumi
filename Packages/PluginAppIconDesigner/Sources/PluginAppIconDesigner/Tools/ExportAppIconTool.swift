import AgentToolKit
import Foundation

public struct ExportAppIconTool: SuperAgentTool {
    public let name = "export_app_icon"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "把 App Icon Designer 中的候选图片导出为 Xcode 可用的 AppIcon.appiconset。默认导出当前选中的候选图。"
        case .english:
            return "Export an App Icon Designer candidate image as an Xcode-ready AppIcon.appiconset. Defaults to the currently selected candidate."
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
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

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "Export app icon set"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        guard let outputDirectory = arguments["outputDirectory"]?.value as? String, !outputDirectory.isEmpty else {
            return "Error: Missing required 'outputDirectory' parameter."
        }

        let requestedArtifactId = arguments["artifactId"]?.value as? String
        let setName = (arguments["setName"]?.value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let outputURL = URL(fileURLWithPath: outputDirectory, isDirectory: true)

        do {
            let artifact = try await MainActor.run {
                let store = AppIconArtifactStore.shared
                if let requestedArtifactId, !requestedArtifactId.isEmpty {
                    guard let artifact = store.artifacts.first(where: { $0.id == requestedArtifactId }) else {
                        throw ExportAppIconToolError.artifactNotFound(requestedArtifactId)
                    }
                    return artifact
                }
                guard let artifact = store.selectedArtifact else {
                    throw ExportAppIconToolError.noSelectedArtifact
                }
                return artifact
            }

            let result = try AppIconExportService().exportAppIconSet(
                sourceImagePath: artifact.sourcePath,
                outputDirectory: outputURL,
                setName: setName?.isEmpty == false ? setName! : "AppIcon"
            )

            await MainActor.run {
                AppIconArtifactStore.shared.setExportURL(result.appIconSetURL)
            }

            return """
            Exported app icon set.
            path: \(result.appIconSetURL.path)
            images: \(result.imageCount)
            """
        } catch {
            await MainActor.run {
                AppIconArtifactStore.shared.setError(error.localizedDescription)
            }
            return "Error: \(error.localizedDescription)"
        }
    }
}

private enum ExportAppIconToolError: LocalizedError {
    case noSelectedArtifact
    case artifactNotFound(String)

    var errorDescription: String? {
        switch self {
        case .noSelectedArtifact:
            return "No app icon candidate is selected."
        case .artifactNotFound(let id):
            return "App icon artifact not found: \(id)"
        }
    }
}
