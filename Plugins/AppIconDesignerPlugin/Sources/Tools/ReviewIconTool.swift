import Foundation
import KernelLumi

// MARK: - Review (sub-agent 视角审核)

/// 渲染当前图标文档，并以「资深 App 图标设计师」人设让 LLM 审核它，返回结构化修改意见。
///
/// 实现走「直接调用 provider」路径（`kernel.llmProvider?.generateText`）：
/// 一次性的 vision 调用，不写消息库、不触发 agent turn、不污染当前对话历史，
/// 只把审核意见作为 tool content 返回。对照 `ReviewPromoImageTool` 与
/// `AutoConversationTitleService` 的直接调用模式。
///
/// 工具是只读的（`riskLevel = .low`，沿用协议默认）：只评审、不修改文档。
public struct ReviewIconTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "review_icon",
        displayName: "Review Icon",
        description: "Render an icon document and ask a senior icon designer persona to critique it, returning concrete revision suggestions. Read-only; does not modify the document."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        var properties = IconToolSupport.baseProperties()
        properties["pixelSize"] = [
            "type": "integer",
            "description": "Optional square render size in pixels. Defaults to 1024 and is capped at 2048."
        ]
        properties["focus"] = [
            "type": "string",
            "description": "Optional area to focus the critique (e.g. 'contrast', 'silhouette', 'legibility', 'balance'). Omit for a full review."
        ]
        return ["type": "object", "properties": .object(properties)]
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "Review icon"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], kernel: KernelLumi) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        let language = IconToolSupport.language(kernel)

        // 1. 解析文档（可选 documentId + scope，回退选中）。
        let (document, scope) = try await IconToolSupport.resolveDocument(arguments, kernel: kernel)

        // 2. 渲染 PNG（复用 PreviewIconTool 的渲染管线）。
        let requestedSize = arguments.int("pixelSize") ?? 1024
        let pixelSize = min(max(requestedSize, 64), 2048)
        let pngData = try await MainActor.run {
            try AppIconExportService().renderPreviewPNG(document: document, pixelSize: pixelSize)
        }

        // 3. 构造带图的直接 LLM 请求（均为值类型/Sendable，可跨 actor 传递）。
        let attachment = LumiImageAttachment(
            mimeType: "image/png",
            base64Data: pngData.base64EncodedString(),
            fileName: "\(document.fileSafeName)-review.png"
        )
        let focus = arguments.string("focus")?.trimmingCharacters(in: .whitespacesAndNewlines)
        let request = LumiLLMRequest(
            messages: Self.designerReviewMessages(
                document: document,
                scope: scope,
                pixelSize: pixelSize,
                focus: focus,
                attachment: attachment
            ),
            model: "",
            tools: [],
            // 同时保留 request 级附件：通用 OpenAI/Anthropic 适配器经 MessageBridge
            // 会把它附加到最后一条 user 消息。
            imageAttachments: [attachment]
        )

        // 4. 直接调 provider（不写消息库、不触发 turn）。provider/model 解析回退与
        //    ReviewPromoImageTool 一致：优先全局选中，回退对话配置。
        //    `any LLMProviderManaging` 非 Sendable，整个调用封闭在 MainActor 隔离的
        //    `runDesignReview` 内，引用不跨隔离边界泄漏。
        do {
            let review = try await Self.runDesignReview(request: request, kernel: kernel)
            let trimmed = review.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty
                ? IconToolSupport.localized(
                    language,
                    en: "Design review returned an empty response. Try a different model or focus area.",
                    zh: "设计评审返回了空内容。请尝试更换模型或聚焦方向后重试。"
                )
                : trimmed
        } catch ReviewAborted.noProvider {
            return IconToolSupport.localized(
                language,
                en: "Review unavailable: no LLM provider registered.",
                zh: "评审不可用：未注册 LLM provider。"
            )
        } catch {
            return IconToolSupport.localized(
                language,
                en: "Design review failed: \(error.localizedDescription). If the selected model does not support vision, switch to a vision-capable model and retry.",
                zh: "设计评审失败：\(error.localizedDescription)。若当前模型不支持视觉，请切换到支持视觉的模型后重试。"
            )
        }
    }

    /// 内部中止错误，用于把「无 provider」从 MainActor 隔离方法里抛出。
    private enum ReviewAborted: Error {
        case noProvider
    }

    /// 在 MainActor 上解析 provider 并发起一次性 LLM 调用，返回审核正文。
    @MainActor
    private static func runDesignReview(request: LumiLLMRequest, kernel: KernelLumi) async throws -> String {
        guard let providerManager = kernel.llmProvider else {
            throw ReviewAborted.noProvider
        }
        let providerID = kernel.llmProvider?.selectedProviderID
        let model = kernel.llmProvider?.selectedModel
        return try await providerManager.generateText(request, providerID: providerID, model: model)
    }

    // MARK: - 设计师人设 prompt

    /// 构造审核请求的消息序列：system（资深图标设计师人设 + 结构化输出约束）+ user（文档/尺寸上下文）。
    ///
    /// 图片同时编码进 user 消息的 `metadata["imageAttachments"]`。原因：部分 provider
    ///（如阿里云 AliyunAnthropicRequestBuilder）在构造请求体时**只读消息 metadata**，
    /// 不读 `request.imageAttachments`；而通用 OpenAI/Anthropic 适配器两者都支持。
    /// 同时写两处可兼容所有 provider，确保 LLM 一定能看到渲染图。
    private static func designerReviewMessages(
        document: IconDocument,
        scope: IconScope,
        pixelSize: Int,
        focus: String?,
        attachment: LumiImageAttachment
    ) -> [LumiChatMessage] {
        // system 用占位 conversationID；直接调用路径不落库，不参与真实对话。
        let conversationID = UUID()
        let system = LumiChatMessage(
            conversationID: conversationID,
            role: .system,
            content: designerSystemPrompt(focus: focus)
        )
        let userMetadata = LumiImageAttachmentMetadata.encode([attachment])
        let user = LumiChatMessage(
            conversationID: conversationID,
            role: .user,
            content: """
            Please critique this app icon.

            Title: \(document.title)
            Canvas: \(Int(document.width))×\(Int(document.height))
            Render size: \(pixelSize)×\(pixelSize)
            Scope: \(scope.rawValue)
            Layers: \(document.layers.count)

            The rendered icon is attached. Review it strictly from a senior icon designer's perspective.
            """,
            metadata: userMetadata
        )
        return [system, user]
    }

    /// 资深 App 图标设计师人设，输出结构化审核意见。
    private static let designerSystemPromptBase = """
    You are a senior app icon designer with years of experience crafting icons for iOS, iPadOS, macOS, and watchOS. You have an exceptional eye for silhouette, visual weight, contrast, and how an icon reads at a tiny home-screen size as well as in the App Store.

    You are given a rendered app icon. Critique it as if reviewing a teammate's draft before it ships. Be specific, honest, and constructive — never generic.

    Evaluate across these dimensions as relevant:
    - Silhouette & recognizability: does the icon read as a single clear shape at small sizes? Is the focal subject obvious within ~1 second?
    - Visual weight & balance: is the composition centered and stable, or lopsided/cramped? Mind safe margins — content should not crowd the edges.
    - Contrast & legibility: does the foreground stand out from the background across light and dark contexts? Avoid low-contrast color pairs.
    - Color & palette: is the palette cohesive, brand-aligned, and harmonious? Watch for muddy or clashing colors.
    - Depth & hierarchy: are shadows, gradients, and layering used purposefully, or do they add noise?
    - Platform fit: does it feel native to Apple's icon aesthetic (squircle-friendly, not over-detailed, no tiny text)?
    - Scalability: will detail survive being shown at 29pt and 1024px?

    Output strictly in this structure:
    1. **Overall impression** (2-3 sentences).
    2. **Issues** — a prioritized list, most severe first. For each: what's wrong and why it matters at small sizes.
    3. **Suggestions** — concrete, actionable changes that map directly to this designer's building blocks (background paint, shape geometry/position/size, fill, stroke, opacity, shadow, blur, layer order). Prefer the smallest change that fixes the issue.

    Keep it concise and skimmable. Do not redesign the whole icon — point, don't paint.
    """

    private static func designerSystemPrompt(focus: String?) -> String {
        let trimmed = focus?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return designerSystemPromptBase }
        return designerSystemPromptBase + "\n\nFocus this critique primarily on: \(trimmed). Still flag any critical issues in other dimensions, but keep the emphasis on the requested focus."
    }
}
