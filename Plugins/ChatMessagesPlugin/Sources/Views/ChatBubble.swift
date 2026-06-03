import LumiCoreKit
import LumiUI
import SwiftUI

public struct ChatBubble: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    public let message: ChatMessage
    private let messageRenderer: (ChatMessage, Binding<Bool>) -> AnyView?
    @State private var showRawMessage = false

    public init(
        message: ChatMessage,
        messageRenderer: @escaping (ChatMessage, Binding<Bool>) -> AnyView? = { _, _ in nil }
    ) {
        self.message = message
        self.messageRenderer = messageRenderer
    }

    public var body: some View {
        if let rendered = messageRenderer(message, $showRawMessage) {
            rendered
        } else {
            fallbackBubble
        }
    }

    private var fallbackBubble: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(roleTitle)
                    .font(.appMicroEmphasized)
                    .foregroundColor(theme.textSecondary)
                Spacer()
                Text(message.timestamp, style: .time)
                    .font(.appMicro)
                    .foregroundColor(theme.textTertiary)
            }

            Text(message.content)
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(theme.textSecondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var roleTitle: String {
        switch message.role {
        case .user: return "User"
        case .assistant: return "Assistant"
        case .system: return "System"
        case .tool: return "Tool"
        case .status: return "Status"
        case .error: return "Error"
        case .unknown: return "Unknown"
        }
    }
}
