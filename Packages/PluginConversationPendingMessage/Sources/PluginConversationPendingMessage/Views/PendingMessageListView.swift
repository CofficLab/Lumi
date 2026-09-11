import LumiUI
import SwiftUI
import os

/// 待发消息列表视图。
struct PendingMessageListView: View {
    private static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.conversation-pending-message",
        category: "PendingMessageListView"
    )

    @ObservedObject var viewModel: PendingMessageViewModel
    @LumiTheme private var theme

    var body: some View {
        Group {
            if let conversationID = viewModel.selectedConversationID,
               !viewModel.pendingMessages.isEmpty {
                let _ = Self.logger.debug("body evaluated: conversation=\(conversationID.uuidString.prefix(8)), pending=\(viewModel.pendingMessages.count)")
                let showsPosition = viewModel.pendingMessages.count > 1
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    ForEach(Array(viewModel.pendingMessages.enumerated()), id: \.element.id) { index, message in
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            if showsPosition {
                                AppTag(
                                    "\(index + 1)",
                                    systemImage: "list.number",
                                    style: .accent
                                )
                            } else {
                                Image(systemName: "clock.fill")
                                    .font(.appMicroEmphasized)
                                    .foregroundStyle(theme.textTertiary)
                            }

                            Text(message.content)
                                .font(.appCaption)
                                .lineLimit(1)
                                .foregroundStyle(theme.textPrimary)

                            if !message.imageAttachments.isEmpty {
                                AppTag(
                                    "\(message.imageAttachments.count)",
                                    systemImage: "photo"
                                )
                            }

                            if !message.fileAttachments.isEmpty {
                                AppTag(
                                    "\(message.fileAttachments.count)",
                                    systemImage: "doc"
                                )
                            }

                            Spacer(minLength: 0)

                            AppIconButton(
                                systemImage: "xmark",
                                tint: theme.error.opacity(0.8),
                                size: .compact
                            ) {
                                viewModel.cancelPendingMessage(id: message.id)
                            }
                            .help("取消待发送消息")
                        }
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .padding(.vertical, 6)
                        .appSurface(
                            style: .listRow,
                            cornerRadius: DesignTokens.Radius.sm
                        )
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .appSurface(style: .panel, cornerRadius: 0)
            }
        }
        .onAppear {
            let selectedConversation = viewModel.selectedConversationID?.uuidString.prefix(8) ?? "nil"
            Self.logger.info("view appeared: selectedConversation=\(selectedConversation)")
        }
    }
}
