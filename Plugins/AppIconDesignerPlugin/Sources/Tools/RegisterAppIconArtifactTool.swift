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
                    "description": IconToolSupport.description(language, en: "Absolute local path to the image file.", zh: "图片文件的本地绝对路径。")
                ],
                "title": [
                    "type": "string",
                    "description": IconToolSupport.description(language, en: "Short candidate title shown in the preview.", zh: "预览中显示的候选项短标题。")
                ],
                "prompt": [
                    "type": "string",
                    "description": IconToolSupport.description(language, en: "The prompt or design request that produced this image.", zh: "生成该图片的提示词或设计需求。")
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
        let language = IconToolSupport.language(arguments)
        guard let path = arguments["path"]?.value as? String, !path.isEmpty else {
            return IconToolSupport.missingParameter("path", language: language)
        }

        let title = arguments["title"]?.value as? String
        let prompt = arguments["prompt"]?.value as? String

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
