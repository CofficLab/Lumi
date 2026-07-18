import Foundation
import LumiComponentMessage

/// 会话偏好对应的 system prompt 片段默认文案。
///
/// 这些英文 prompt 文案曾硬编码在 `LumiCoreKit` 的
/// `LumiResponseVerbosity` / `LumiConversationLanguage` / `LumiAutomationLevel`
/// 枚举里（`systemPromptFragment` 属性）。按分层架构优化方案 §5 阶段 1，
/// 抽到实现层（`LumiChatKit`）集中管理：核心层不再"知道"这些聊天提示语义，
/// 文案可在此处统一调整/本地化/注入，而无需改动 CoreKit 的领域模型。
///
/// 调用方（`ChatService`、`LanguageChatMiddleware` 等）应通过本类型取片段，
/// 不要直接依赖枚举上的 `systemPromptFragment`（已迁移）。
public enum LumiConversationPromptDefaults {
    /// 语言偏好对应的 system prompt 片段。
    public static func fragment(for language: LumiConversationLanguage) -> String {
        switch language {
        case .chinese:
            "Respond in Chinese unless the user explicitly asks for another language."
        case .english:
            "Respond in English unless the user explicitly asks for another language."
        }
    }

    /// 自动化等级对应的 system prompt 片段。
    public static func fragment(for automation: LumiAutomationLevel) -> String {
        switch automation {
        case .chat:
            "A1 chat mode: do not use tools. Answer conversationally and ask before any action."
        case .build:
            "A2 build mode: use available tools when helpful, but avoid destructive or high-risk actions unless explicitly approved."
        case .autonomous:
            "A3 autonomous mode: use available tools proactively and continue until the user's task is handled. Avoid destructive actions unless explicitly requested."
        }
    }

    /// 回复详略等级对应的 system prompt 片段。
    public static func fragment(for verbosity: LumiResponseVerbosity) -> String {
        switch verbosity {
        case .brief:
            "Be concise. Provide only the essential answer without explanation."
        case .standard:
            "Use a balanced level of detail. Include the answer, key reasoning, and necessary steps without excessive background."
        case .detailed:
            "Be thorough. Include reasoning steps, relevant context, and potential caveats."
        }
    }
}
