import Foundation
import KernelLumi

/// ResumeDesigner 插件 willSendToLLM 钩子
///
/// 在 AgentTurnRunner 构造 LumiLLMRequest 之前被调用，
/// 将 Resume Designer 的使用指南作为 system 消息
/// 注入到 messages 首位，引导 Agent 正确使用工具链。
@MainActor
public struct ResumeDesignerWillSendToLLMHook {
    public init() {}

    /// 执行 willSendToLLM 钩子
    public func execute(
        kernel: KernelLumi,
        messages: [LumiChatMessage]
    ) async -> [LumiChatMessage] {
        guard let conversationID = messages.last?.conversationID else { return messages }

        let guidance = LumiChatMessage(
            conversationID: conversationID,
            role: .system,
            content: """
            Resume Designer manages its own resume library. For every user request such as "help me write my resume", first call resume_create exactly once, choosing a paper preset (a4 or letter) and a starting template (classic, modern, minimal, or blank for fully custom designs driven by the user's own requirements). Each resume is a complete deterministic HTML document composed of one or more .resume-page containers whose CSS width and height exactly match the paper preset; when content grows beyond one page, append another .resume-page container instead of letting content overflow. Collect the user's real experience and tailor wording to the target role; never invent employers, dates, or achievements without confirmation. Import local assets (profile photos and similar) with resume_import_asset and reference only returned relative paths; never use remote resources, scripts, iframes, animations, or external fonts. After each meaningful edit, call resume_lint (it also detects content overflow at runtime) and resume_preview_page to inspect the rendered PNG, then iterate with resume_patch_html. Export with resume_export only when the user selects an output directory; PDF pages are exact paper size with selectable text and print-ready layout.
            """
        )

        return [guidance] + messages
    }
}
