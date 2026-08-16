import AgentToolKit
import Foundation

// MARK: - Review (sub-agent 视角审核)

/// 渲染当前图标文档，并以「资深 App 图标设计师」人设让 LLM 审核它，返回结构化修改意见。
///
/// KernelCore 精简内核不内置 LLM provider：工具通过宿主注入的
/// `IconDesignerRuntime.designReviewLLM`（`IconDesignReviewLLMProviding`）发起
/// 一次性的视觉评审调用；未注入时返回「评审不可用」提示。
///
/// 工具是只读的（`riskLevel = .low`）：只评审、不修改文档。
public struct ReviewIconTool: SuperAgentTool {
    public let name = "review_icon"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Render an icon document and ask a senior icon designer persona to critique it, returning concrete revision suggestions. Read-only; does not modify the document."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        var properties = IconToolSupport.baseProperties()
        properties["pixelSize"] = [
            "type": "integer",
            "description": "Optional square render size in pixels. Defaults to 1024 and is capped at 2048."
        ]
        properties["focus"] = [
            "type": "string",
            "description": "Optional area to focus the critique (e.g. 'contrast', 'silhouette', 'legibility', 'balance'). Omit for a full review."
        ]
        return ["type": "object", "properties": properties]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "Review icon"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let language = IconToolSupport.language

        // 1. 解析文档（可选 documentId + scope，回退选中）。
        let (document, scope) = try await IconToolSupport.resolveDocument(arguments)

        // 2. 渲染 PNG（复用 PreviewIconTool 的渲染管线）。
        let requestedSize = IconToolSupport.double(arguments, "pixelSize", default: 1024)
        let pixelSize = Int(min(max(requestedSize, 64), 2048))
        let pngData = try await MainActor.run {
            try AppIconExportService().renderPreviewPNG(document: document, pixelSize: pixelSize)
        }

        let attachment = ImageAttachment(
            data: pngData,
            mimeType: "image/png",
            fileName: "\(document.fileSafeName)-review.png"
        )
        let focus = IconToolSupport.string(arguments, "focus")?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // 3. 取宿主注入的评审服务；未注入时返回不可用提示。
        let reviewService = await MainActor.run { IconDesignerRuntime.designReviewLLM }
        guard let reviewService else {
            return IconToolSupport.localized(
                language,
                en: "Review unavailable: no LLM review service registered.",
                zh: "评审不可用：未注册 LLM 评审服务。"
            )
        }

        do {
            let prompt = Self.designerReviewPrompt(
                document: document,
                scope: scope,
                pixelSize: pixelSize,
                focus: focus
            )
            let review = try await reviewService.generateDesignReview(prompt: prompt, image: attachment)
            let trimmed = review.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty
                ? IconToolSupport.localized(
                    language,
                    en: "Design review returned an empty response. Try a different model or focus area.",
                    zh: "设计评审返回了空内容。请尝试更换模型或聚焦方向后重试。"
                )
                : trimmed
        } catch {
            return IconToolSupport.localized(
                language,
                en: "Design review failed: \(error.localizedDescription). If the selected model does not support vision, switch to a vision-capable model and retry.",
                zh: "设计评审失败：\(error.localizedDescription)。若当前模型不支持视觉，请切换到支持视觉的模型后重试。"
            )
        }
    }

    // MARK: - 设计师人设 prompt

    /// 构造评审请求的提示词：资深图标设计师人设 + 结构化输出约束 + 文档/尺寸上下文。
    private static func designerReviewPrompt(
        document: IconDocument,
        scope: IconScope,
        pixelSize: Int,
        focus: String?
    ) -> String {
        let context = """
        Please critique this app icon.

        Title: \(document.title)
        Canvas: \(Int(document.width))×\(Int(document.height))
        Render size: \(pixelSize)×\(pixelSize)
        Scope: \(scope.rawValue)
        Layers: \(document.layers.count)

        The rendered icon is attached. Review it strictly from a senior icon designer's perspective.
        """
        return designerSystemPrompt(focus: focus) + "\n\n" + context
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
