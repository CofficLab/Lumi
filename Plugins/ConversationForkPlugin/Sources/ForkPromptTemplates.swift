import Foundation
import LumiKernel

/// 续接对话所用的提示词模板。
///
/// 把当前对话的历史喂给模型，让它产出一段「最小可用上下文」摘要；
/// 再把这段摘要包进一个 user 消息注入到新对话里，让续写无缝衔接。
public enum ForkPromptTemplates {
    /// 生成摘要时给模型的 system 指令。
    ///
    /// 设计目标：提炼出续写所需的「目标 / 已完成 / 阻塞点 / 下一步 / 关键约束」，
    /// 而不是逐条复述对话，从而让新对话轻装上阵、摆脱原对话可能的纠缠。
    public static let summarySystemPrompt = """
    You are a conversation summarizer for an AI coding assistant. \
    Condense the following conversation into the minimal context needed to seamlessly continue the work in a fresh chat. \
    Preserve, in the SAME language as the conversation:
    - User's overall goal
    - Steps already taken and their results
    - The current blocker or open question (why the previous chat got stuck)
    - Concrete next steps to take
    - Key files, symbols, commands, constraints, or decisions

    Be concise. Use a short bulleted structure. Do NOT restate the full dialogue. \
    Do NOT add commentary. Output only the summary.
    """

    /// 把对话历史拼成单条文本，供摘要请求引用。
    ///
    /// - Parameter messages: 已过滤后的可见消息（user / assistant）。
    /// - Returns: 形如 `User: ...` / `Assistant: ...` 的逐条拼接。
    public static func renderHistory(_ messages: [LumiChatMessage]) -> String {
        messages.map { message in
            let speaker = message.role == .user ? "User" : "Assistant"
            let body = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return "\(speaker): \(body)"
        }
        .joined(separator: "\n\n")
    }

    /// 注入到新对话首条 user 消息的续写提示。
    ///
    /// - Parameter summary: 由模型（或回退逻辑）产出的上下文摘要。
    /// - Returns: 包了分隔线的续写指令，告诉模型「这是延续的上下文，直接继续，不必复述」。
    public static func continuePrompt(summary: String) -> String {
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        return """
        This is a continuation from a previous conversation. Here is the context summary:

        ———————————————————————————
        \(trimmed)
        ———————————————————————————

        Please pick up from here and continue helping me. Do not restate the summary; just proceed with the next steps.
        """
    }
}
