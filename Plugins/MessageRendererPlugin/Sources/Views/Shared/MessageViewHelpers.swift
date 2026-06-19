import AppKit
import LumiCoreKit
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
