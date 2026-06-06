import LumiCoreKit
import LumiUI
import MessageRendererPlugin
import SwiftUI

/// 智谱错误消息布局（与 App 默认 ErrorMessage 保持一致：header + 红色气泡）
struct ErrorMessageLayout<Content: View>: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    let message: ChatMessage
    @Binding var showRawMessage: Bool
    @ViewBuilder let content: () -> Content

    private var zh: Bool {
        MessageRendererRuntime.languagePreference == .chinese
    }

    private var titleText: String {
        zh ? "错误" : "Error"
    }

    private var copyContent: String {
        if !message.content.isEmpty {
            return message.content
        }
        return message.rawErrorDetail ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            MessageHeaderView {
                HStack(alignment: .center, spacing: 6) {
                    AvatarView.error
                    AppIdentityRow(title: titleText)
                    ProviderBadge()
                }
            } trailing: {
                HStack(alignment: .center, spacing: 12) {
                    CopyMessageButton(
                        content: copyContent,
                        showFeedback: .constant(false)
                    )

                    Text(formatTimestamp(message.timestamp))
                        .font(.appMicro)
                        .foregroundColor(theme.textSecondary)

                    RawMessageToggleButton(showRawMessage: $showRawMessage)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .messageBubbleStyle(role: message.role, isError: true)
        }
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(for: date) ?? ""
    }
}
