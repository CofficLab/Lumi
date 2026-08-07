import LumiKernel
import LumiUI
import SwiftUI

/// 工具栏视图：显示当前对话的消息数量
struct MessageCountToolbarView: View {
    @LumiTheme private var theme
    let kernel: LumiKernel

    // 只订阅 conversations（selectedConversationID 无命名事件，必须 box）。
    // 消息增删由 .onLumiMessagesDidChange 精确覆盖，count 缓存进 @State，
    // 无需 messageManagerBox。不挂在 kernel 全局总线上。
    @StateObject private var conversationsBox = ObservableConversationsBox()
    @State private var count: Int = 0

    private var selectedConversationID: UUID? {
        conversationsBox.service?.selectedConversationID
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "number")
                .font(.system(size: 11))
            Text("\(count)")
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
        }
        .foregroundColor(theme.textSecondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(theme.surface.opacity(0.5))
        )
        .help("Messages in current conversation: \(count)")
        .task {
            conversationsBox.bind(kernel.conversations)
            refreshCount()
        }
        .onLumiMessagesDidChange { eventConversationID in
            // 只关心当前会话的消息变更（nil 表示全量刷新）。
            guard eventConversationID == nil
                || eventConversationID == selectedConversationID else { return }
            refreshCount()
        }
        .onChange(of: selectedConversationID) { _, _ in
            // 切换会话时重算计数。
            refreshCount()
        }
    }

    private func refreshCount() {
        guard let conversationID = selectedConversationID,
              let messageManager = kernel.messageManager else {
            count = 0
            return
        }
        count = messageManager.messages(for: conversationID).count
    }
}