import LumiKernel
import LumiUI
import SwiftUI

struct PendingMessageListView: View {
    @ObservedObject var kernel: LumiKernel
    @ObservedObject var box: ObservableMessageSendingBox
    @LumiTheme private var theme

    private var conversationID: UUID? {
        kernel.conversations?.selectedConversationID
    }

    private var messages: [LumiPendingMessage] {
        guard let conversationID else { return [] }
        return box.service.pendingMessages(for: conversationID)
    }

    var body: some View {
        if !messages.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("待发送消息 \(messages.count)")
                        .font(.appMicroEmphasized)
                    Spacer()
                }
                .foregroundColor(theme.textSecondary)

                ForEach(messages) { message in
                    HStack(spacing: 8) {
                        Text(message.content)
                            .font(.appMicro)
                            .foregroundColor(theme.textPrimary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button {
                            guard let conversationID else { return }
                            box.service.cancelPendingMessage(id: message.id, in: conversationID)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(theme.textTertiary)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .background(theme.textPrimary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(theme.textPrimary.opacity(0.025))
        }
    }
}
