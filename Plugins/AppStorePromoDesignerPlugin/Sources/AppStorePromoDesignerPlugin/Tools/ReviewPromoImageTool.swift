import AppStorePromoKit
import Foundation
import LumiKernel

// MARK: - Review (sub-agent 视角审核)

/// 渲染单张促销图，并以「资深 App Store 创意设计师」人设让 LLM 审核它，返回结构化修改意见。
///
/// 实现走「直接调用 provider」路径（`kernel.llmProvider?.generateText`）：
/// 一次性的 vision 调用，不写消息库、不触发 agent turn、不污染当前对话历史，
/// 只把审核意见作为 tool content 返回。对照 `AutoConversationTitleService` 的直接调用模式。
///
/// 工具是只读的（`riskLevel = .low`，沿用协议默认）：只评审、不修改 HTML。
public struct ReviewPromoImageTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "app_store_promo_review_image",
        displayName: "Review promo image",
        description: "Render a promotional image and ask a senior designer persona to critique it, returning concrete revision suggestions. Read-only; does not modify HTML."
    )
    public init() {}
    public var inputSchema: LumiJSONValue {
        var properties = PromoToolSupport.baseProperties(includeImage: true)
        properties["displayType"] = ["type": "string", "description": "Exact App Store display type. Defaults to the first preset for the task family."]
        properties["focus"] = ["type": "string", "description": "Optional area to focus the critique (e.g. 'typography', 'hierarchy', 'color'). Omit for a full review."]
        return ["type": "object", "properties": .object(properties), "required": ["taskId", "imageId"]]
    }
    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        // 1. 解析 scope + 读图 + lint（与 PreviewPromoImageTool 一致）。
        let scope = try await PromoToolSupport.resolveScope(arguments, kernel: kernel)
        let storagePath = try await PromoToolSupport.storagePath(for: scope)
        let image = try PromoToolSupport.store.readImage(
            storagePath: storagePath,
            taskSlug: try PromoToolSupport.required("taskId", arguments),
            imageSlug: try PromoToolSupport.required("imageId", arguments)
        )
        let type = arguments.string("displayType") ?? AppStorePromoDisplaySpec.presets(for: image.task.deviceFamily).first?.displayType
        guard let type, let preset = AppStorePromoDisplaySpec.preset(for: type), preset.family == image.task.deviceFamily else {
            throw PromoToolSupport.ToolArgumentError.invalid("displayType")
        }
        let report = try PromoToolSupport.store.lintImage(storagePath: storagePath, taskSlug: image.task.id, imageSlug: image.image.id)
        guard report.isValid else { throw AppStorePromoStoreError.invalidHTML(report.errors) }

        // 2. 渲染 PNG（复用 PreviewPromoImageTool 的渲染管线）。
        let data = try await AppStorePromoHTMLExporter.exportPNG(html: image.html, fileURL: image.htmlURL, preset: preset)

        // 3. 构造带图的直接 LLM 请求（均为值类型/Sendable，可跨 actor 传递）。
        let attachment = LumiImageAttachment(
            mimeType: "image/png",
            base64Data: data.base64EncodedString(),
            fileName: "\(image.image.id)-\(type).png"
        )
        let focus = arguments.string("focus")?.trimmingCharacters(in: .whitespacesAndNewlines)
        let request = LumiLLMRequest(
            messages: Self.designerReviewMessages(
                task: image.task,
                image: image.image,
                displayType: type,
                focus: focus,
                attachment: attachment
            ),
            model: "",
            tools: [],
            // 同时保留 request 级附件：通用 OpenAI/Anthropic 适配器经 MessageBridge
            // 会把它附加到最后一条 user 消息（见 attachRequestImages）。
            imageAttachments: [attachment]
        )

        // 4. 直接调 provider（不写消息库、不触发 turn）。provider/model 解析回退与
        //    AutoConversationTitleService 一致：优先全局选中，回退对话配置。
        //    `any LLMProviderManaging` 非 Sendable，整个调用封闭在 MainActor 隔离的
        //    `runDesignReview` 内，引用不跨隔离边界泄漏。
        do {
            let review = try await Self.runDesignReview(request: request, kernel: kernel)
            let trimmed = review.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Design review returned an empty response. Try a different model or focus area." : trimmed
        } catch ReviewAborted.noProvider {
            return "Review unavailable: no LLM provider registered."
        } catch {
            return "Design review failed: \(error.localizedDescription). If the selected model does not support vision, switch to a vision-capable model and retry."
        }
    }

    /// 内部中止错误，用于把「无 provider」从 MainActor 隔离方法里抛出。
    private enum ReviewAborted: Error {
        case noProvider
    }

    /// 在 MainActor 上解析 provider 并发起一次性 LLM 调用，返回审核正文。
    ///
    /// 单独成方法是为了让 `any LLMProviderManaging` 引用始终留在 MainActor 侧，
    /// 不经 `MainActor.run` 闭包返回值跨隔离边界（该类型非 Sendable）。
    @MainActor
    private static func runDesignReview(request: LumiLLMRequest, kernel: LumiKernel) async throws -> String {
        guard let providerManager = kernel.llmProvider else {
            throw ReviewAborted.noProvider
        }
        let providerID = kernel.llmProvider?.selectedProviderID
        let model = kernel.llmProvider?.selectedModel
        return try await providerManager.generateText(request, providerID: providerID, model: model)
    }

    // MARK: - 设计师人设 prompt

    /// 构造审核请求的消息序列：system（资深设计师人设 + 结构化输出约束）+ user（任务/图片/尺寸上下文）。
    ///
    /// 图片同时编码进 user 消息的 `metadata["imageAttachments"]`。原因：部分 provider
    ///（如阿里云 AliyunAnthropicRequestBuilder）在构造请求体时**只读消息 metadata**，
    /// 不读 `request.imageAttachments`；而通用 OpenAI/Anthropic 适配器两者都支持。
    /// 同时写两处可兼容所有 provider，确保 LLM 一定能看到渲染图。
    private static func designerReviewMessages(
        task: AppStorePromoTask,
        image: AppStorePromoImage,
        displayType: String,
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
            Please critique this App Store promotional artwork.

            Task: \(task.title)
            App: \(task.appName)
            Device family: \(task.deviceFamily.rawValue)
            Locale: \(task.localeIdentifier)
            Image: \(image.title) (order \(image.order + 1))
            Rendered display type: \(displayType)

            The image is attached. Review it strictly from a senior creative designer's perspective.
            """,
            metadata: userMetadata
        )
        return [system, user]
    }

    /// 资深 App Store 创意设计师人设，输出结构化审核意见。
    private static let designerSystemPromptBase = """
    You are a senior App Store creative designer with years of experience crafting high-converting promotional artwork (hero/promo images) for the App Store. You have an exceptional eye for visual hierarchy, typography, color, and composition on mobile and desktop canvases.

    You are given a rendered promotional image. Critique it as if reviewing a teammate's draft before it ships to the App Store. Be specific, honest, and constructive — never generic.

    Evaluate across these dimensions as relevant:
    - Visual hierarchy & focal point: what does the eye land on first? Is it the intended subject?
    - Typography & copy legibility: headline weight, size, contrast against the background, safe-area margins.
    - Color & contrast: palette cohesion, brand alignment, readability at small sizes.
    - Composition & whitespace: balance, alignment, crowding, padding relative to the device bezel.
    - Device-fit: how it reads at the exact App Store display size and aspect ratio.
    - First impression: would it stop a user from scrolling in the store?

    Output strictly in this structure:
    1. **Overall impression** (2-3 sentences).
    2. **Issues** — a prioritized list, most severe first. For each: what's wrong and why it matters.
    3. **Suggestions** — concrete, actionable changes that map directly to HTML/CSS edits (e.g. "increase h1 font-size", "add 8% top padding", "raise copy contrast"). Prefer the smallest change that fixes the issue.

    Keep it concise and skimmable. Do not rewrite the HTML for them — point, don't paint.
    """

    private static func designerSystemPrompt(focus: String?) -> String {
        let trimmed = focus?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return designerSystemPromptBase }
        return designerSystemPromptBase + "\n\nFocus this critique primarily on: \(trimmed). Still flag any critical issues in other dimensions, but keep the emphasis on the requested focus."
    }
}