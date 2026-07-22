import Foundation
import LumiKernel
import LumiKernel
import LLMKit

/// MiniMax 视频生成工具：通过 MiniMax API 生成视频并返回 mp4 文件。
///
/// 四步流程：
/// 1. 提交视频生成任务（获取 task_id）
/// 2. 轮询任务状态（最多 3 分钟）
/// 3. 获取下载链接（24 小时有效）
/// 4. 下载视频文件（10–50 MB mp4）
///
/// - Tool ID: `minimax_generate_video`
/// - Emoji: 🎬
/// - Tags: `.network`, `"generative"`, `"expensive"`
/// - API Key: 复用 TokenPlan 的 `DevAssistant_ApiKey_MiniMax`
public struct MiniMaxVideoTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "minimax_generate_video",
        displayName: LumiPluginLocalization.string("MiniMax Video", bundle: .module),
        description: LumiPluginLocalization.string(
            "Generate a video clip using MiniMax AI. Supports text-to-video (6–10 seconds, 720P–1080P). Returns a video file attachment.",
            bundle: .module
        )
    )

    public static let tags: Set<LumiToolTag> = [
        .network,
        "generative",
        "expensive",
    ]

    public nonisolated static let emoji = "🎬"

    private let client: any MiniMaxVideoClientProtocol

    // MARK: - Init

    public init(
        client: any MiniMaxVideoClientProtocol = MiniMaxVideoClient(apiKeyProvider: {
            APIKeyStore.shared.loadMigratingLegacyUserDefaults(forKey: "DevAssistant_ApiKey_MiniMax")
        })
    ) {
        self.client = client
    }

    // MARK: - LumiAgentTool

    public var name: String { "minimax_generate_video" }

    public var toolDescription: String { Self.info.description }

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "prompt": .object([
                    "type": .string("string"),
                    "description": .string(
                        "Detailed video description, including subject, action, scene, camera movement, lighting style, etc. Example: 'A cat playing piano in a cozy cafe, warm lighting, cinematic dolly-in shot.'"
                    ),
                ]),
                "model": .object([
                    "type": .string("string"),
                    "description": .string("Video generation model. Default: MiniMax-Hailuo-2.3"),
                    "enum": .array([
                        .string("MiniMax-Hailuo-2.3"),
                        .string("Hailuo-02"),
                        .string("T2V-01-Director"),
                        .string("T2V-01"),
                    ]),
                ]),
                "duration": .object([
                    "type": .string("integer"),
                    "description": .string("Video duration in seconds: 6 or 10. Default: 6"),
                ]),
                "resolution": .object([
                    "type": .string("string"),
                    "description": .string("Video resolution: 720P, 768P, or 1080P. Only Hailuo-2.3 and Hailuo-02 support 1080P. Default: 768P"),
                ]),
                "prompt_optimizer": .object([
                    "type": .string("boolean"),
                    "description": .string("Whether to use AI to enhance the prompt for better quality. Default: false"),
                ]),
                "fast_pretreatment": .object([
                    "type": .string("boolean"),
                    "description": .string("Whether to use fast preprocessing (slightly lower quality, faster generation). Default: false"),
                ]),
                "aigc_watermark": .object([
                    "type": .string("boolean"),
                    "description": .string("Whether to add an AIGC watermark. Default: false"),
                ]),
            ]),
            "required": .array([.string("prompt")]),
        ])
    }

    public func execute(
        arguments: [String: LumiJSONValue],
        context: LumiToolExecutionContext
    ) async throws -> String {
        try context.checkCancellation()

        // 1. 解析参数
        guard let prompt = arguments["prompt"]?.stringValue, !prompt.isEmpty else {
            return "**Error:** `prompt` is required and must be a non-empty string."
        }

        let model = arguments["model"]?.stringValue ?? MiniMaxVideoModel.defaultModel.rawValue
        let duration = intArgument(arguments["duration"]) ?? MiniMaxVideoDuration.defaultDuration.rawValue
        let resolution = arguments["resolution"]?.stringValue ?? MiniMaxVideoResolution.defaultResolution.rawValue
        let promptOptimizer = arguments["prompt_optimizer"]?.boolValue
        let fastPretreatment = arguments["fast_pretreatment"]?.boolValue
        let aigcWatermark = arguments["aigc_watermark"]?.boolValue

        // 2. 构建 shouldContinue 闭包（支持取消）
        let shouldContinue: @Sendable () async -> Bool = {
            !context.isCancelled
        }

        // 3. 调用 client 执行四步交付链
        do {
            let asset = try await client.generate(
                prompt: prompt,
                model: model,
                duration: duration,
                resolution: resolution,
                promptOptimizer: promptOptimizer,
                fastPretreatment: fastPretreatment,
                aigcWatermark: aigcWatermark,
                shouldContinue: shouldContinue,
                pollInterval: MiniMaxVideoConstants.pollInterval
            )

            try context.checkCancellation()

            // 4. 通过 context.attachImage() 回传视频
            context.attachImage(
                LumiImageAttachment(
                    mimeType: asset.mimeType,
                    base64Data: asset.base64Data,
                    fileName: asset.fileName
                )
            )

            // 5. 返回 Markdown 元信息
            return formatResult(
                asset: asset,
                model: model,
                duration: duration,
                resolution: resolution,
                prompt: prompt
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as MiniMaxVideoError {
            return formatError(error)
        } catch {
            return "**Error:** \(error.localizedDescription)"
        }
    }

    // MARK: - Formatters

    private func formatResult(
        asset: MiniMaxVideoGeneratedAsset,
        model: String,
        duration: Int,
        resolution: String,
        prompt: String
    ) -> String {
        let sizeDesc = formatByteCount(asset.byteCount)
        return """
        ## 🎬 Video Generated

        - **Prompt:** \(prompt)
        - **Model:** \(model)
        - **Duration:** \(duration) seconds
        - **Resolution:** \(resolution)
        - **File Name:** \(asset.fileName)
        - **File Size:** \(sizeDesc)

        The video (video/mp4) is attached and can be viewed directly.
        """
    }

    private func formatError(_ error: MiniMaxVideoError) -> String {
        switch error {
        case .missingAPIKey:
            return "**Error:** MiniMax API Key is not configured. Please add your API key in Lumi settings first."
        default:
            return "**Error:** \(error.localizedDescription)"
        }
    }

    private func formatByteCount(_ byteCount: Int64) -> String {
        if byteCount < 1024 {
            return "\(byteCount) B"
        } else if byteCount < 1024 * 1024 {
            return String(format: "%.1f KB", Double(byteCount) / 1024)
        } else {
            return String(format: "%.1f MB", Double(byteCount) / (1024 * 1024))
        }
    }

    private func intArgument(_ value: LumiJSONValue?) -> Int? {
        switch value {
        case .int(let intValue): return intValue
        case .double(let doubleValue): return Int(doubleValue)
        default: return nil
        }
    }
}
