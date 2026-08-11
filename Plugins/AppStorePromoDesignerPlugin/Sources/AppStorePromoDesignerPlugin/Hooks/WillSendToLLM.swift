import Foundation
import LumiKernel

/// PromoDesigner 插件 willSendToLLM 钩子
///
/// 在 AgentTurnRunner 构造 LumiLLMRequest 之前被调用，
/// 将 App Store Promo Designer 的使用指南作为 system 消息
/// 注入到 messages 首位，引导 Agent 正确使用工具链。
@MainActor
public struct PromoDesignerWillSendToLLMHook {
    public init() {}

    /// 执行 willSendToLLM 钩子
    public func execute(
        kernel: LumiKernel,
        messages: [LumiChatMessage]
    ) async -> [LumiChatMessage] {
        guard let conversationID = messages.last?.conversationID else { return messages }

        let guidance = LumiChatMessage(
            conversationID: conversationID,
            role: .system,
            content: """
            App Store Promo Designer manages its own task library. For every user request such as "create promotional images for my app", first call app_store_promo_create_task exactly once, then create all requested artwork as multiple images under that task with app_store_promo_create_image. Each image can contain independent language versions; create them with app_store_promo_add_image_language and always pass localeIdentifier when reading, editing, patching, or previewing a localized version. Each version is a complete deterministic HTML document. Import local assets with app_store_promo_import_asset, reference only returned relative paths, and never use remote resources, scripts, iframes, animations, or external fonts. Use responsive CSS so one image works at every display type in its device family. After each meaningful edit, call app_store_promo_preview_image and inspect its attached PNG. To get a senior designer's perspective before finalizing, call app_store_promo_review_image to receive structured critique and concrete revision suggestions, then iterate with app_store_promo_patch_html. Source HTML and assets stay in plugin-managed storage; export only when the user selects an output directory.
            """
        )

        return [guidance] + messages
    }
}
