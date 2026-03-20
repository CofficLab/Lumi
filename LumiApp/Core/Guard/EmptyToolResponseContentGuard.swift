import Foundation

/// 空 content + toolCalls 的展示增强纯策略 guard。
///
/// 当 `content` 仅包含空白且同时存在非空 `toolCalls` 时，
/// 生成用于展示的工具摘要内容。
struct EmptyToolResponseContentGuard {
    enum Result {
        case proceed
        case updatedContent(String)
    }

    func evaluate(
        content: String,
        toolCalls: [ToolCall]?,
        languagePreference: LanguagePreference
    ) -> Result {
        guard let toolCalls, !toolCalls.isEmpty else {
            return .proceed
        }

        guard content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .proceed
        }

        let toolSummary = toolCalls.map(\.name).joined(separator: "\n")
        let prefix: String = (languagePreference == .chinese)
            ? "正在执行 \(toolCalls.count) 个工具："
            : "Executing \(toolCalls.count) tools:"

        return .updatedContent(prefix + "\n" + toolSummary)
    }
}

