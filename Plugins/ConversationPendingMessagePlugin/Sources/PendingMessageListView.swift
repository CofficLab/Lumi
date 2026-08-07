import LumiKernel
import LumiUI
import SwiftUI

struct PendingMessageListView: View {
    let kernel: LumiKernel
    @ObservedObject var box: ObservableMessageSendingBox
    @LumiTheme private var theme

    // conversationID 由 .onLumiSelectedConversationDidChange 事件更新。
    // 不挂 kernel 全局总线。
    @State private var conversationID: UUID?

    private var messages: [LumiPendingMessage] {
        guard let conversationID else { return [] }
        return box.service.pendingMessages(for: conversationID)
    }

    var body: some View {
        // 用 Group 包裹条件分支，并把 .task 挂在 Group 上：
        // messages 依赖 conversationID（来自 conversationsBox.service，绑定前为 nil），分支首次必为 false。
        // 若把 .task 挂进 if 内，分支不渲染时 bind 永不执行（死锁）。Group 恒存在，保证绑定。
        Group {
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
        .task {
            conversationID = kernel.conversations?.selectedConversationID
        }
        .onLumiSelectedConversationDidChange { newID in
            conversationID = newID
        }
    }
}
