import LumiKernel
import LumiUI
import SwiftUI

/// 工具栏视图：显示当前对话的消息数量
struct MessageCountToolbarView: View {
    @LumiTheme private var theme
    let kernel: LumiKernel

    // 只订阅 conversations + messageManager 两个 service：count 同时依赖
    // 「当前对话 ID」与「该对话的消息列表」，任一变化都需重算。
    // 不挂在 kernel 全局总线上，project/settings 等无关服务变更不会触发这里刷新。
    @StateObject private var conversationsBox = ObservableConversationsBox()
    @StateObject private var messageManagerBox = ObservableMessageManagerBox()

    var body: some View {
        let count = currentMessageCount()
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
            messageManagerBox.bind(kernel.messageManager)
        }
    }

    private func currentMessageCount() -> Int {
        guard let conversationID = conversationsBox.service?.selectedConversationID,
              let messageManager = messageManagerBox.service else {
            return 0
        }
        return messageManager.messages(for: conversationID).count
    }
}