import KitAgentTool
import KernelCore
import KitLocalization
import LumiUI
import KitMarkdown
import ProviderConversation
import ProviderMessage
import ProviderMessageRendering
import ProviderMessageSender
import ProviderToolManager
import AppKit
import LumiUI

enum MessageViewHelpers {
    static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    static func formatTimestamp(_ date: Date) -> String {
        timestampFormatter.string(from: date)
    }

    /// Human-readable tool-call duration.
    ///
    /// Three tiers: <1s → milliseconds, <60s → one-decimal seconds, else "Xm Ys".
    /// Centralized here (was duplicated privately in two views).
    static func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 1 {
            return "\(Int(duration * 1000))ms"
        }
        if duration < 60 {
            return String(format: "%.1fs", duration)
        }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return "\(minutes)m \(seconds)s"
    }

    /// Format a duration given in milliseconds (e.g. `latencyMs`) into a
    /// human-readable string. Delegates to `formatDuration` on seconds.
    static func formatMilliseconds(_ ms: Double) -> String {
        formatDuration(ms / 1000.0)
    }

    /// Pretty-print a tool-call's JSON argument string.
    ///
    /// Returns `nil` for empty / `"{}"`; otherwise a sorted,
    /// pretty-printed representation. Invalid but non-empty payloads are
    /// returned verbatim so the user can still inspect malformed/legacy calls.
    static func formatToolCallArguments(_ arguments: String) -> String? {
        var trimmed = arguments.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "{}" else {
            return nil
        }

        // 兼容旧版本流式累积产生的 `{}{...}`：前面的 `{}` 只是“尚无参数”
        // 占位符，不能作为真实调用参数的一部分展示。
        if trimmed.hasPrefix("{}") {
            let remainder = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
            if remainder.first == "{" || remainder.first == "[" {
                trimmed = remainder
            }
        }

        guard let data = trimmed.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data) else {
            return trimmed
        }
        if let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys]),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            return prettyString
        }
        return trimmed
    }

    static func formatModelName(_ name: String) -> String {
        let parts = name.split(separator: "-")
        if parts.count > 2, let lastPart = parts.last, lastPart.allSatisfy({ $0.isNumber }) {
            return parts.dropLast().joined(separator: "-")
        }
        return name
    }

    static func metadataItems(for message: Message) -> [String] {
        var items: [String] = []
        if let providerID = message.providerID, !providerID.isEmpty {
            items.append(providerID)
        }
        if let cacheHitRate = cacheHitRateItem(for: message) {
            items.append(cacheHitRate)
        }
        return items
    }

    static func cacheHitRateItem(for message: Message) -> String? {
        guard let cached = intMetadata(message, MessageTokenMetadata.cachedInputKey),
              cached > 0
        else {
            return nil
        }

        let total = intMetadata(message, MessageTokenMetadata.cacheTotalInputKey)
            ?? intMetadata(message, MessageTokenMetadata.inputKey)
            ?? 0
        guard total > 0 else { return nil }

        let percentage = min(100.0, max(0.0, (Double(cached) / Double(total)) * 100.0))
        return "cache \(String(format: "%.0f", percentage))%"
    }

    private static func intMetadata(_ message: Message, _ key: String) -> Int? {
        guard let raw = message.metadata[key] else { return nil }
        return Int(raw)
    }

    /// 进程级缓存:`NSFullUserName()` 走目录服务查询,历史上每次 body 求值
    /// (每个用户行、每次滚动重物化)都重跑一次;用户名在进程生命周期内不变。
    private static let cachedUserDisplayName: String = {
        let fullName = NSFullUserName()
        return fullName.isEmpty ? NSUserName() : fullName
    }()

    static func userDisplayName() -> String {
        cachedUserDisplayName
    }

    static func avatarKind(for role: MessageRole) -> ChatAvatarKind {
        switch role {
        case .user: .user
        case .assistant: .assistant
        case .tool: .tool
        case .system: .system
        case .error: .error
        case .status: .status
        }
    }

    static func headerTitle(for message: Message) -> String {
        switch message.role {
        case .user: return userDisplayName()
        case .assistant:
            if let modelName = message.modelName, !modelName.isEmpty {
                return formatModelName(modelName)
            }
            return "Lumi"
        case .tool: return "Tool"
        case .system: return "System"
        case .error: return "Error"
        case .status: return "Status"
        }
    }

    static func copyContent(for message: Message) -> String {
        if message.content.isEmpty {
            rawDescription(for: message)
        } else {
            message.content
        }
    }

    static func rawDescription(for message: Message) -> String {
        [
            "id: \(message.id.uuidString)",
            "role: \(message.role.rawValue)",
            "provider: \(message.providerID ?? "-")",
            "model: \(message.modelName ?? "-")",
            "renderKind: \(message.renderKind ?? "-")",
            "toolCallID: \(message.toolCallID ?? "-")",
            "rawError: \(message.rawErrorDetail ?? "-")",
            "metadata: \(message.metadata)",
        ].joined(separator: "\n")
    }
}
