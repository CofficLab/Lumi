import Foundation
import LumiKernel
import LLMKit

/// 图片生成工具：通过 MiniMax API 生成图片，并把图片链接（24 小时有效）返回给调用方。
///
/// 单次 POST 请求，直接返回图片 URL 列表（无需异步轮询）。
///
/// - Tool ID: `generate_image`
/// - Emoji: 🖼️
/// - Tags: `.network`, `"generative"`
/// - API Key: 复用 TokenPlan 的 `DevAssistant_ApiKey_MiniMax`
public struct MiniMaxImageTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "generate_image",
        displayName: LumiPluginLocalization.string("Image", bundle: .module),
        description: LumiPluginLocalization.string(
            "Generate images from text prompts using MiniMax AI. Supports text-to-image and image-to-image (via subject_reference for character likeness), multiple models (image-01, image-01-live with style options), various aspect ratios, and batch generation (up to 9 images). Returns temporary image URLs (valid for 24 hours).",
            bundle: .module
        )
    )

    public static let tags: Set<LumiToolTag> = [
        .network,
        "generative",
    ]

    public nonisolated static let emoji = "🖼️"

    private let client: any MiniMaxImageClientProtocol
    private let recordStore: MiniMaxImageRecordStore?

    // MARK: - Init

    init(
        client: any MiniMaxImageClientProtocol = MiniMaxImageClient(apiKeyProvider: {
            APIKeyStore.shared.loadMigratingLegacyUserDefaults(forKey: "DevAssistant_ApiKey_MiniMax")
        }),
        recordStore: MiniMaxImageRecordStore? = nil
    ) {
        self.client = client
        self.recordStore = recordStore
    }

    // MARK: - LumiAgentTool

    public var name: String { "generate_image" }

    public var toolDescription: String { Self.info.description }

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "prompt": .object([
                    "type": .string("string"),
                    "description": .string(
                        "Detailed text description of the image to generate, up to 1500 characters. Example: 'A man in a white t-shirt, standing front view, outdoors, with the Venice Beach sign in the background. Fashion photography in 90s documentary style, film grain, photorealistic.'"
                    ),
                ]),
                "model": .object([
                    "type": .string("string"),
                    "description": .string("Image generation model. Default: image-01. Use 'image-01-live' for style options (manga, watercolor, etc.)."),
                    "enum": .array([
                        .string("image-01"),
                        .string("image-01-live"),
                    ]),
                ]),
                "subject_reference": .object([
                    "type": .string("array"),
                    "description": .string("Subject reference for image-to-image generation. Each item should be an object with 'type' (currently only 'character' for portrait) and 'image_file' (public URL or base64 data URL). For best results, upload a front-facing single person photo. Image requirements: JPG/JPEG/PNG, under 10MB."),
                    "items": .object([
                        "type": .string("object"),
                        "properties": .object([
                            "type": .object([
                                "type": .string("string"),
                                "description": .string("Subject type. Currently only 'character' (portrait) is supported."),
                                "enum": .array([.string("character")]),
                            ]),
                            "image_file": .object([
                                "type": .string("string"),
                                "description": .string("Reference image file. Supports public URL or Base64 Data URL (data:image/jpeg;base64,...). For best results, upload a front-facing single person photo."),
                            ]),
                        ]),
                        "required": .array([.string("type"), .string("image_file")]),
                    ]),
                ]),
                "style_type": .object([
                    "type": .string("string"),
                    "description": .string("Style type for image-01-live model only. Options: 漫画 (manga), 元气 (energetic), 中世纪 (medieval), 水彩 (watercolor)."),
                ]),
                "style_weight": .object([
                    "type": .string("number"),
                    "description": .string("Style weight for image-01-live model, range (0, 1]. Default: 0.8."),
                ]),
                "aspect_ratio": .object([
                    "type": .string("string"),
                    "description": .string("Image aspect ratio. Default: 1:1. Options: 1:1, 16:9, 4:3, 3:2, 2:3, 3:4, 9:16, 21:9 (21:9 only for image-01)."),
                ]),
                "n": .object([
                    "type": .string("integer"),
                    "description": .string("Number of images to generate, range [1, 9]. Default: 1."),
                ]),
                "prompt_optimizer": .object([
                    "type": .string("boolean"),
                    "description": .string("Whether to use AI to enhance the prompt for better quality. Default: false."),
                ]),
                "aigc_watermark": .object([
                    "type": .string("boolean"),
                    "description": .string("Whether to add an AIGC watermark to generated images. Default: false."),
                ]),
            ]),
            "required": .array([.string("prompt")]),
        ])
    }

    public func execute(
        arguments: [String: LumiJSONValue],
        kernel: LumiKernel
    ) async throws -> String {
        try kernel.checkCancellation()

        // 1. 解析参数
        guard let prompt = arguments["prompt"]?.stringValue, !prompt.isEmpty else {
            return "**Error:** `prompt` is required and must be a non-empty string."
        }

        let model = arguments["model"]?.stringValue ?? MiniMaxImageModel.defaultModel.rawValue
        let styleType = arguments["style_type"]?.stringValue
        let styleWeight = floatArgument(arguments["style_weight"])
        let aspectRatio = arguments["aspect_ratio"]?.stringValue
        let width = intArgument(arguments["width"])
        let height = intArgument(arguments["height"])
        let n = intArgument(arguments["n"]) ?? 1
        let promptOptimizer = arguments["prompt_optimizer"]?.boolValue ?? false
        let aigcWatermark = arguments["aigc_watermark"]?.boolValue ?? false

        // 解析 subject_reference（图生图）
        let subjectReference = parseSubjectReference(arguments["subject_reference"])

        // 2. 插入 pending 记录
        let recordID = await recordStore?.insertPendingRecord(
            prompt: prompt,
            model: model,
            subjectReference: subjectReference,
            styleType: styleType,
            styleWeight: styleWeight,
            aspectRatio: aspectRatio,
            width: width,
            height: height,
            n: n,
            promptOptimizer: promptOptimizer,
            aigcWatermark: aigcWatermark
        )

        // 3. 调用 client 生成图片
        do {
            let asset = try await client.generate(
                prompt: prompt,
                model: model,
                subjectReference: subjectReference,
                styleType: styleType,
                styleWeight: styleWeight,
                aspectRatio: aspectRatio,
                width: width,
                height: height,
                n: n,
                promptOptimizer: promptOptimizer,
                aigcWatermark: aigcWatermark
            )

            try kernel.checkCancellation()

            // 4. 标记成功
            if let recordID {
                await recordStore?.markSuccess(
                    recordID: recordID,
                    taskID: asset.taskID,
                    imageURLs: asset.imageURLs,
                    successCount: asset.successCount,
                    failedCount: asset.failedCount
                )
            }

            // 5. 格式化返回结果
            return formatResult(
                asset: asset,
                model: model,
                aspectRatio: aspectRatio,
                n: n,
                prompt: prompt,
                styleType: styleType
            )
        } catch is CancellationError {
            if let recordID {
                await recordStore?.markCancelled(recordID: recordID, taskID: nil)
            }
            throw CancellationError()
        } catch let error as MiniMaxImageError {
            if let recordID {
                await recordStore?.markFailed(recordID: recordID, taskID: nil, errorMessage: error.localizedDescription)
            }
            return formatError(error)
        } catch {
            if let recordID {
                await recordStore?.markFailed(recordID: recordID, taskID: nil, errorMessage: error.localizedDescription)
            }
            return "**Error:** \(error.localizedDescription)"
        }
    }

    // MARK: - Formatters

    private func formatResult(
        asset: MiniMaxImageGeneratedAsset,
        model: String,
        aspectRatio: String?,
        n: Int,
        prompt: String,
        styleType: String?
    ) -> String {
        var lines = [
            "## 🖼️ Images Generated",
            "",
            "- **Prompt:** \(prompt)",
            "- **Model:** \(model)",
            "- **Requested:** \(n) image(s)",
            "- **Success:** \(asset.successCount) image(s)",
        ]

        if asset.failedCount > 0 {
            lines.append("- **Failed (content safety):** \(asset.failedCount) image(s)")
        }
        if let aspectRatio {
            lines.append("- **Aspect Ratio:** \(aspectRatio)")
        }
        if let styleType {
            lines.append("- **Style:** \(styleType)")
        }

        lines.append("")
        lines.append("### Generated Images")
        lines.append("")

        for (index, url) in asset.imageURLs.enumerated() {
            let urlString = url.absoluteString
            lines.append("**Image \(index + 1):** (valid for **24 hours**)")
            lines.append("")
            lines.append("> \(urlString)")
            lines.append("")
        }

        lines.append("Click the links above to view or download the generated images in your browser.")
        return lines.joined(separator: "\n")
    }

    private func formatError(_ error: MiniMaxImageError) -> String {
        switch error {
        case .missingAPIKey:
            return "**Error:** MiniMax API Key is not configured. Please add your API key in Lumi settings first."
        default:
            return "**Error:** \(error.localizedDescription)"
        }
    }

    private func intArgument(_ value: LumiJSONValue?) -> Int? {
        switch value {
        case .int(let intValue): return intValue
        case .double(let doubleValue): return Int(doubleValue)
        default: return nil
        }
    }

    private func floatArgument(_ value: LumiJSONValue?) -> Float? {
        switch value {
        case .int(let intValue): return Float(intValue)
        case .double(let doubleValue): return Float(doubleValue)
        default: return nil
        }
    }

    /// 解析 subject_reference 数组参数。
    ///
    /// 期望格式：
    /// ```json
    /// [
    ///   { "type": "character", "image_file": "https://..." }
    /// ]
    /// ```
    private func parseSubjectReference(_ value: LumiJSONValue?) -> [MiniMaxImageSubjectReference]? {
        guard case .array(let items) = value, !items.isEmpty else {
            return nil
        }

        var references: [MiniMaxImageSubjectReference] = []
        for item in items {
            guard case .object(let dict) = item,
                  case .string(let type) = dict["type"] ?? .null,
                  case .string(let imageFile) = dict["image_file"] ?? .null,
                  !imageFile.isEmpty else {
                continue
            }
            references.append(MiniMaxImageSubjectReference(type: type, imageFile: imageFile))
        }

        return references.isEmpty ? nil : references
    }
}
