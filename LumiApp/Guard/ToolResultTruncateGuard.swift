import Foundation

/// 截断过长的 tool result content 的纯策略 guard。
struct ToolResultTruncateGuard {
    enum Result {
        case proceed
        case truncated(String)
    }

    func evaluate(content: String, maxLen: Int) -> Result {
        guard content.count > maxLen else {
            return .proceed
        }

        let prefix = String(content.prefix(maxLen))
        let updatedContent = "\(prefix)\n\n... [Tool output truncated to \(maxLen) characters]"
        return .truncated(updatedContent)
    }
}

