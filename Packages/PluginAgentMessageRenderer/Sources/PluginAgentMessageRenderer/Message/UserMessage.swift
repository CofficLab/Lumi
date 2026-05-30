import SwiftUI
import LumiCoreKit
import LumiUI

/// 负责完整渲染一条用户消息（包含头部与正文）
public struct UserMessage: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    public let message: ChatMessage
    @Binding var showRawMessage: Bool

    /// 当前 macOS 登录用户名称
    private var currentUserName: String {
        let fullName = NSFullUserName()
        return fullName.isEmpty ? NSUserName() : fullName
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            header

            VStack(alignment: .leading, spacing: 8) {
                if !message.images.isEmpty {
                    AppImagePreviewGrid(imageDataList: message.images.map(\.data))
                }

                if !message.content.isEmpty {
                    CollapsibleMessageContent(
                        rawContent: message.content,
                        collapsedLineLimit: 20
                    ) {
                        PlainTextMessageContentView(
                            content: message.content,
                            monospaced: false
                        )
                    }
                }
            }
            .messageBubbleStyle(role: message.role, isError: message.isError)
        }
    }

    // MARK: - Header

    private var header: some View {
        MessageHeaderView {
            HStack(alignment: .center, spacing: 6) {
                AvatarView.user
                AppIdentityRow(title: currentUserName)
            }
        } trailing: {
            HStack(alignment: .center, spacing: 12) {
                CopyMessageButton(
                    content: message.content,
                    showFeedback: .constant(false)
                )

                ResendButton(action: resend)

                AppIdentityRow(
                    title: formatTimestamp(message.timestamp),
                    titleColor: theme.textSecondary
                )

                // RawMessageToggleButton(showRawMessage: $showRawMessage)
            }
        }
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(for: date) ?? ""
    }

    private func resend() {
        MessageRendererRuntime.enqueueText(message.content)
    }
}
