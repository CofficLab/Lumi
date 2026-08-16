import AgentToolKit
import AppStorePromoKit
import Foundation

// MARK: - Review (sub-agent 视角审核)

/// 渲染单张促销图，并以「资深 App Store 创意设计师」人设让 LLM 审核它，返回结构化修改意见。
///
/// KernelCore 精简内核不内置 LLM provider：工具通过宿主注入的
/// `PromoDesignerRuntime.designReviewLLM`（`PromoDesignReviewLLMProviding`）发起
/// 一次性的视觉评审调用；未注入时返回「评审不可用」提示。
///
/// 工具是只读的（`riskLevel = .low`）：只评审、不修改 HTML。
public struct ReviewPromoImageTool: SuperAgentTool {
    public let name = "app_store_promo_review_image"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Render a promotional image and ask a senior designer persona to critique it, returning concrete revision suggestions. Read-only; does not modify HTML."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        var properties = PromoToolSupport.baseProperties(includeImage: true)
        properties["displayType"] = ["type": "string", "description": "Exact App Store display type. Defaults to the first preset for the task family."]
        properties["focus"] = ["type": "string", "description": "Optional area to focus the critique (e.g. 'typography', 'hierarchy', 'color'). Omit for a full review."]
        return ["type": "object", "properties": properties, "required": ["taskId", "imageId"]]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        PromoToolSupport.localized(PromoToolSupport.language, en: "Review promo image", zh: "评审促销图")
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let language = PromoToolSupport.language

        // 1. 解析 scope + 读图 + lint（与 PreviewPromoImageTool 一致）。
        let scope = try await PromoToolSupport.resolveScope(arguments)
        let storagePath = try await PromoToolSupport.storagePath(for: scope)
        let image = try PromoToolSupport.store.readImage(
            storagePath: storagePath,
            taskSlug: try PromoToolSupport.required("taskId", arguments),
            imageSlug: try PromoToolSupport.required("imageId", arguments),
            localeIdentifier: PromoToolSupport.string(arguments, "localeIdentifier")
        )
        let type = PromoToolSupport.string(arguments, "displayType")
            ?? AppStorePromoDisplaySpec.presets(for: image.task.deviceFamily).first?.displayType
        guard let type, let preset = AppStorePromoDisplaySpec.preset(for: type), preset.family == image.task.deviceFamily else {
            throw PromoToolSupport.ToolArgumentError.invalid("displayType")
        }
        let report = try PromoToolSupport.store.lintImage(
            storagePath: storagePath,
            taskSlug: image.task.id,
            imageSlug: image.image.id,
            localeIdentifier: image.localeIdentifier
        )
        guard report.isValid else { throw AppStorePromoStoreError.invalidHTML(report.errors) }

        // 2. 渲染 PNG（复用 PreviewPromoImageTool 的渲染管线）。
        let data = try await AppStorePromoHTMLExporter.exportPNG(html: image.html, fileURL: image.htmlURL, preset: preset)
        let attachment = ImageAttachment(
            data: data,
            mimeType: "image/png",
            fileName: "\(image.image.id)-\(image.localeIdentifier)-\(type).png"
        )
        let focus = PromoToolSupport.string(arguments, "focus")?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // 3. 取宿主注入的评审服务；未注入时返回不可用提示。
        let reviewService = await MainActor.run { PromoDesignerRuntime.designReviewLLM }
        guard let reviewService else {
            return PromoToolSupport.localized(
                language,
                en: "Review unavailable: no LLM review service registered.",
                zh: "评审不可用：未注册 LLM 评审服务。"
            )
        }

        do {
            let prompt = Self.designerReviewPrompt(
                task: image.task,
                image: image.image,
                localeIdentifier: image.localeIdentifier,
                displayType: type,
                focus: focus
            )
            let review = try await reviewService.generateDesignReview(prompt: prompt, image: attachment)
            let trimmed = review.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty
                ? PromoToolSupport.localized(
                    language,
                    en: "Design review returned an empty response. Try a different model or focus area.",
                    zh: "设计评审返回了空内容。请尝试更换模型或聚焦方向后重试。"
                )
                : trimmed
        } catch {
            return PromoToolSupport.localized(
                language,
                en: "Design review failed: \(error.localizedDescription). If the selected model does not support vision, switch to a vision-capable model and retry.",
                zh: "设计评审失败：\(error.localizedDescription)。若当前模型不支持视觉，请切换到支持视觉的模型后重试。"
            )
        }
    }

    // MARK: - 设计师人设 prompt

    /// 构造评审请求的提示词：资深设计师人设 + 结构化输出约束 + 任务/尺寸上下文。
    private static func designerReviewPrompt(
        task: AppStorePromoTask,
        image: AppStorePromoImage,
        localeIdentifier: String,
        displayType: String,
        focus: String?
    ) -> String {
        let context = """
        Please critique this App Store promotional artwork.

        Task: \(task.title)
        App: \(task.appName)
        Device family: \(task.deviceFamily.rawValue)
        Locale: \(localeIdentifier)
        Image: \(image.title) (order \(image.order + 1))
        Rendered display type: \(displayType)

        The image is attached. Review it strictly from a senior creative designer's perspective.
        """
        return designerSystemPrompt(focus: focus) + "\n\n" + context
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
