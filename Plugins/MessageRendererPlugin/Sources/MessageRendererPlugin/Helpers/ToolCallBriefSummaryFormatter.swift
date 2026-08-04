import LumiKernel

/// V1(brief)模式下工具调用列表的纯文本摘要格式化。
enum ToolCallBriefSummaryFormatter {
    static func summaryText(for toolCalls: [LumiToolCall]) -> String {
        toolCalls
            .map(title(for:))
            .filter { !$0.isEmpty }
            .joined(separator: "  ·  ")
    }

    static func title(for toolCall: LumiToolCall) -> String {
        let description = toolCall.displayDescription?.trimmingCharacters(in: .whitespacesAndNewlines)
        return description.flatMap { $0.isEmpty ? nil : $0 } ?? "执行工具"
    }
}
