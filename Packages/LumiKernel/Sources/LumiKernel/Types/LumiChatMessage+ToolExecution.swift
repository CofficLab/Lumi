import Foundation

public extension LumiChatMessage {
    /// True when the assistant message only exists to report tool execution with no substantive reply.
    var isToolExecutionOnly: Bool {
        guard role == .assistant else { return false }
        guard !content.isEmpty else { return false }
        let hasToolCall = toolCalls?.isEmpty == false
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return hasToolCall && (trimmedContent.isEmpty || trimmedContent == "...")
    }
}
