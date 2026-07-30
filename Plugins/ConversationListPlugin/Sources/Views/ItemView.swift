import LumiKernel
import LumiUI
import SwiftUI

/// 会话项视图 - 纯静态展示
public struct ItemView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    public let conversation: LumiConversationSummary
    public let onDelete: () -> Void
    public let onPin: () -> Void

    public init(conversation: LumiConversationSummary, onDelete: @escaping () -> Void, onPin: @escaping () -> Void) {
        self.conversation = conversation
        self.onDelete = onDelete
        self.onPin = onPin
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.appMicro)
                .foregroundColor(theme.textTertiary)
                .padding(3)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    if conversation.order == 0 {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9))
                            .foregroundColor(theme.primary)
                    }

                    Text(conversation.displayTitle)
                        .font(.appMicroEmphasized)
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Text(relativeTime(from: conversation.updatedAt))
                    .font(.appMicro)
                    .foregroundColor(theme.textSecondary)
            }

            Spacer()
        }
        .contextMenu {
            Button {
                onPin()
            } label: {
                Label(
                    conversation.order == 0 ? "Unpin" : "Pin",
                    systemImage: conversation.order == 0 ? "pin.slash" : "pin"
                )
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label(LumiPluginLocalization.string("Delete", bundle: .module), systemImage: "trash")
            }
        }
    }

    private func relativeTime(from date: Date) -> String {
        let delta = Date().timeIntervalSince(date)
        guard delta >= 0 else { return "Just now" }

        let minutes = Int(delta) / 60
        if minutes < 60 {
            return minutes < 1 ? "Just now" : "\(minutes)m ago"
        }

        let hours = minutes / 60
        if hours < 24 {
            return "\(hours)h ago"
        }

        let days = hours / 24
        return "\(days)d ago"
    }
}