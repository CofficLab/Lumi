import ProviderConversation
import ProviderMessage
import SwiftUI

/// 消息计数工具栏视图
struct MessageCountToolbarView: View {
    let messages: any MessageManaging
    @ObservedObject var state: MessageCountToolbarState

    @State private var count: Int = 0
    @State private var isPopoverPresented = false

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
        .help(String(format: LumiPluginLocalization.string("Messages in current conversation: %lld", bundle: .module), count))
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            MessageCountPopover(count: count)
        }
        .task(id: "\(state.selectedConversationID?.uuidString ?? "nil")-\(state.messageRefreshRevision)") {
            await Task.yield()
            guard !Task.isCancelled else { return }
            refreshCount()
        }
    }

    private func refreshCount() {
        guard let conversationID = state.selectedConversationID else {
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
                    text: LumiPluginLocalization.string("Count includes all messages in the current conversation.", bundle: .module)
                )
                explanationRow(
                    icon: "arrow.left.arrow.right",
                    text: LumiPluginLocalization.string("Each user + assistant pair counts as 2 messages.", bundle: .module)
                )
                explanationRow(
                    icon: "wrench.and.screwdriver",
                    text: LumiPluginLocalization.string("Tool calls and results are also counted individually.", bundle: .module)
                )
                explanationRow(
                    icon: "clock.arrow.circlepath",
                    text: LumiPluginLocalization.string("Updates in real-time as messages are sent or received.", bundle: .module)
                )
            }

            Divider()

            HStack {
                Text(LumiPluginLocalization.string("Current:", bundle: .module))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text(String(format: LumiPluginLocalization.string("%lld messages", bundle: .module), count))
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
