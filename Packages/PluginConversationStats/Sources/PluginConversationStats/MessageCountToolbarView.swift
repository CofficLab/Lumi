import ProviderConversation
import ProviderMessage
import SwiftUI

/// 消息计数工具栏视图
struct MessageCountToolbarView: View {
    let conversations: any ConversationManaging
    let messages: any MessageManaging

    @State private var selectedConversationID: UUID?
    @State private var count: Int = 0
    @State private var isPopoverPresented = false

    // 持有观察者令牌，随视图生命周期自动释放
    @State private var conversationObserver: (any SelectedConversationObserverHandle)?
    @State private var messageObserver: (any MessageInsertedObserverHandle)?

    var body: some View {
        Button {
            isPopoverPresented.toggle()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "number")
                    .font(.system(size: 10))
                Text("\(count)")
                    .font(.system(size: 10, weight: .medium))
                    .monospacedDigit()
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Color.secondary.opacity(0.15),
                in: RoundedRectangle(cornerRadius: 5, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(.plain)
        .help("Messages in current conversation: \(count)")
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            MessageCountPopover(count: count)
        }
        .task {
            selectedConversationID = conversations.selectedConversationID
            // 注册会话切换观察
            conversationObserver = conversations.addSelectedConversationObserver { newID in
                selectedConversationID = newID
            }
            // 注册消息插入观察
            messageObserver = messages.addMessageInsertedObserver { _, conversationID in
                // 只关心当前会话的消息变更
                if conversationID == selectedConversationID || selectedConversationID == nil {
                    Task(priority: .utility) { @MainActor in
                        await Task.yield()
                        guard !Task.isCancelled else { return }
                        refreshCount()
                    }
                }
            }
        }
        .task(id: selectedConversationID) {
            await Task.yield()
            guard !Task.isCancelled else { return }
            refreshCount()
        }
    }

    private func refreshCount() {
        guard let conversationID = selectedConversationID else {
            count = 0
            return
        }
        count = messages.messageCount(for: conversationID)
    }
}

// MARK: - Popover

private struct MessageCountPopover: View {
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LumiPluginLocalization.string("Message Count", bundle: .module))
                .font(.system(size: 12, weight: .semibold))

            VStack(alignment: .leading, spacing: 6) {
                explanationRow(
                    icon: "message",
                    text: "Count includes all messages in the current conversation."
                )
                explanationRow(
                    icon: "arrow.left.arrow.right",
                    text: "Each user + assistant pair counts as 2 messages."
                )
                explanationRow(
                    icon: "wrench.and.screwdriver",
                    text: "Tool calls and results are also counted individually."
                )
                explanationRow(
                    icon: "clock.arrow.circlepath",
                    text: "Updates in real-time as messages are sent or received."
                )
            }

            Divider()

            HStack {
                Text(LumiPluginLocalization.string("Current:", bundle: .module))
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
