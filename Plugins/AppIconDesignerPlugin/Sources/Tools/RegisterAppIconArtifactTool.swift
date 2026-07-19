import Foundation
import LumiKernel

public struct RegisterAppIconArtifactTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "register_app_icon_artifact",
        displayName: "Register App Icon Artifact",
        description: "Register an existing image file as an app icon candidate and show it in the App Icon Designer preview."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
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

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "Register app icon candidate"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        let language = IconToolSupport.language(context)
        guard let path = arguments["path"]?.anyValue as? String, !path.isEmpty else {
            return IconToolSupport.missingParameter("path", language: language)
        }

        let title = arguments["title"]?.anyValue as? String
        let prompt = arguments["prompt"]?.anyValue as? String

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
