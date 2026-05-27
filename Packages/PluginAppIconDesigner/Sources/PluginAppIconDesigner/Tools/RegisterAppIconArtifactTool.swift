import AgentToolKit
import Foundation

public struct RegisterAppIconArtifactTool: SuperAgentTool {
    public let name = "register_app_icon_artifact"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "把已有图片文件注册为 App 图标设计候选，并在 App Icon Designer 预览区显示。"
        case .english:
            return "Register an existing image file as an app icon candidate and show it in the App Icon Designer preview."
        }
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

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        guard let path = arguments["path"]?.value as? String, !path.isEmpty else {
            return "Error: Missing required 'path' parameter."
        }

        let title = arguments["title"]?.value as? String
        let prompt = arguments["prompt"]?.value as? String

        do {
            let artifact = try await MainActor.run {
                try AppIconArtifactStore.shared.registerImage(path: path, title: title, prompt: prompt)
            }
            return """
            Registered app icon artifact.
            artifactId: \(artifact.id)
            path: \(artifact.sourcePath)
            """
        } catch {
            await MainActor.run {
                AppIconArtifactStore.shared.setError(error.localizedDescription)
            }
            return "Error: \(error.localizedDescription)"
        }
    }
}
