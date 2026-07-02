import Foundation

extension LumiChatMessage {
    /// Whether the assistant message only represents tool execution without a substantive reply.
    public var isToolExecutionOnly: Bool {
        guard role == .assistant,
              let toolCalls,
              !toolCalls.isEmpty
        else {
            return false
        }

        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else {
            return true
        }

        let lines = trimmedContent
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let firstLine = lines.first else {
            return true
        }

        let isToolSummary = firstLine.hasPrefix("正在执行 ") || firstLine.hasPrefix("Executing ")
        return isToolSummary && lines.count <= toolCalls.count + 1
    }
}
