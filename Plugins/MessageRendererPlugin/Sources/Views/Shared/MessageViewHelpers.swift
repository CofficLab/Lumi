import LumiCoreMessage
import AppKit
import LumiKernel
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

    /// Pretty-print a tool-call's JSON argument string.
    ///
    /// Returns `nil` for empty / `"{}" / invalid JSON; otherwise a sorted,
    /// pretty-printed representation. Centralized here (was private in a view).
    static func formatToolCallArguments(_ arguments: String) -> String? {
        guard !arguments.isEmpty, arguments != "{}",
              let data = arguments.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data)
        else {
            return nil
        }
        if let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys]),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            return prettyString
        }
        return arguments
    }

    static func formatModelName(_ name: String) -> String {
        let parts = name.split(separator: "-")
        if parts.count > 2, let lastPart = parts.last, lastPart.allSatisfy({ $0.isNumber }) {
            return parts.dropLast().joined(separator: "-")
        }
        return name
    }

    static func metadataItems(for message: LumiChatMessage) -> [String] {
        var items: [String] = []
        if let providerID = message.providerID, !providerID.isEmpty {
            items.append(providerID)
        }
        if let modelName = message.modelName, !modelName.isEmpty {
            items.append(formatModelName(modelName))
        }
        return items
    }

    static func userDisplayName() -> String {
        let fullName = NSFullUserName()
        return fullName.isEmpty ? NSUserName() : fullName
    }

    static func avatarKind(for role: LumiChatMessageRole) -> ChatAvatarKind {
        switch role {
        case .user: .user
        case .assistant: .assistant
        case .tool: .tool
        case .system: .system
        case .error: .error
        case .status: .status
        }
    }

    static func headerTitle(for message: LumiChatMessage) -> String {
        switch message.role {
        case .user: userDisplayName()
        case .assistant: "Lumi"
        case .tool: "Tool"
        case .system: "System"
        case .error: "Error"
        case .status: "Status"
        }
    }

    static func copyContent(for message: LumiChatMessage) -> String {
        if message.content.isEmpty {
            rawDescription(for: message)
        } else {
            message.content
        }
    }

    static func rawDescription(for message: LumiChatMessage) -> String {
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
