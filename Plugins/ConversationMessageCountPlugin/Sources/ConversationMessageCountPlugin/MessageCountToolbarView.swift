import LumiKernel
import LumiKernel
import LumiUI
import SwiftUI

/// 工具栏视图：显示当前对话的消息数量
struct MessageCountToolbarView: View {
    @LumiTheme private var theme
    @ObservedObject var kernel: LumiKernel

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
    }

    private func currentMessageCount() -> Int {
        guard let conversationID = kernel.conversations?.selectedConversationID,
              let messageManager = kernel.messageManager else {
            return 0
        }
        return messageManager.messages(for: conversationID).count
    }
}