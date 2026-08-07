import LumiKernel
import LumiUI
import SwiftUI

/// 工具栏视图：显示当前对话的消息数量
struct MessageCountToolbarView: View {
    @LumiTheme private var theme
    let kernel: LumiKernel

    // selectedConversationID 由 .onLumiSelectedConversationDidChange 事件更新；
    // 消息增删由 .onLumiMessagesDidChange 精确覆盖。count 缓存进 @State。
    // 不挂 kernel 全局总线。
    @State private var selectedConversationID: UUID?
    @State private var count: Int = 0
    @State private var isPopoverPresented = false

    var body: some View {
        Button {
            isPopoverPresented.toggle()
        } label: {
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
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help("Messages in current conversation: \(count)")
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            MessageCountPopover(count: count)
        }
        .task {
            selectedConversationID = kernel.conversations?.selectedConversationID
            refreshCount()
        }
        .onLumiSelectedConversationDidChange { newID in
            selectedConversationID = newID
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

private struct MessageCountPopover: View {
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Message Count")
                .font(.system(size: 12, weight: .semibold))

            VStack(alignment: .leading, spacing: 6) {
                explanationRow(icon: "message", text: "Count includes all messages in the current conversation.")
                explanationRow(icon: "arrow.left.arrow.right", text: "Each user + assistant pair counts as 2 messages.")
                explanationRow(icon: "wrench.and.screwdriver", text: "Tool calls and results are also counted individually.")
                explanationRow(icon: "clock.arrow.circlepath", text: "Updates in real-time as messages are sent or received.")
            }

            Divider()

            HStack {
                Text("Current:")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text("\(count) messages")
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
            }
        }
        .padding(10)
        .frame(width: 260)
    }

    private func explanationRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 16)
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(.primary)
        }
    }
}