import AgentToolKit
import Foundation

public struct RegisterAppIconArtifactTool: SuperAgentTool {
    public let name = "register_app_icon_artifact"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Register an existing image file as an app icon candidate and show it in the App Icon Designer preview."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "path": [
                    "type": "string",
                    "description": "Absolute local path to the image file."
                ],
                "title": [
                    "type": "string",
                    "description": "Short candidate title shown in the preview."
                ],
                "prompt": [
                    "type": "string",
                    "description": "The prompt or design request that produced this image."
                ],
            ],
            "required": ["path"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "Register app icon candidate"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let language = IconToolSupport.language
        guard let path = IconToolSupport.string(arguments, "path"), !path.isEmpty else {
            return IconToolSupport.missingParameter("path", language: language)
        }

        let title = IconToolSupport.string(arguments, "title")
        let prompt = IconToolSupport.string(arguments, "prompt")

        do {
            let artifact = try await MainActor.run {
                try AppIconArtifactStore.shared.registerImage(path: path, title: title, prompt: prompt)
            }
            return IconToolSupport.localized(
                language,
                en: """
                Registered app icon artifact.
                artifactId: \(artifact.id)
                path: \(artifact.sourcePath)
                """,
                zh: """
                已注册应用图标候选项。
                候选项ID: \(artifact.id)
                路径: \(artifact.sourcePath)
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
