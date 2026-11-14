import ProviderMessage
import SwiftUI

/// header 栏右侧的 token 用量指示器。
///
/// 展示当前对话的**总** token 数；点击后弹出 popover 展示输入 / 输出拆分。
struct TokenUsageHeaderView: View {
    let messages: any MessageManaging
    let state: TokenUsageToolbarState

    @State private var stats = TokenUsageStats.empty
    @State private var isPopoverPresented = false
    @State private var selectedConversationID: UUID?
    @State private var messageRefreshRevision = 0
    @State private var observerHandle: (any TokenUsageToolbarState.ObserverHandle)?

    var body: some View {
        Button {
            isPopoverPresented.toggle()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "number")
                    .font(.system(size: 10, weight: .medium))
                Text(totalLabel)
                    .font(.system(size: 10, weight: .medium))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .foregroundColor(stats.isEmpty ? .secondary : .primary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Color.secondary.opacity(stats.isEmpty ? 0.12 : 0.15),
                in: RoundedRectangle(cornerRadius: 5, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(helpText)
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            TokenUsagePopover(stats: stats)
        }
        .onChange(of: selectedConversationID) { _, newValue in
            if newValue == nil {
                isPopoverPresented = false
            }
        }
        .task(id: "\(selectedConversationID?.uuidString ?? "nil")-\(messageRefreshRevision)") {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            await refresh()
        }
        .onAppear {
            guard observerHandle == nil else { return }
            selectedConversationID = state.selectedConversationID
            observerHandle = state.addObserver { event in
                switch event {
                case let .selectedConversationChanged(id):
                    selectedConversationID = id
                case let .messagesChanged(conversationID):
                    guard conversationID == selectedConversationID else { return }
                    messageRefreshRevision &+= 1
                }
            }
        }
        .onDisappear {
            observerHandle?.cancel()
            observerHandle = nil
        }
    }

    /// 总 token 数的紧凑写法（不足 1000 直接显示原值）。
    private var totalLabel: String {
        guard !stats.isEmpty else { return "—" }
        return TokenCountFormatter.compact(stats.totalTokens)
    }

    private var helpText: String {
        guard !stats.isEmpty else {
            return pluginLocalization.string("Token usage unavailable: click for details")
        }
        return String(
            format: pluginLocalization.string("Total tokens: %@ (%lld requests)"),
            TokenCountFormatter.compact(stats.totalTokens),
            stats.requestCount
        )
    }

    private func refresh() async {
        guard let conversationID = selectedConversationID else {
            stats = .empty
            return
        }
        let snapshot = await messages.messagesSnapshot(in: conversationID)
        guard !Task.isCancelled, selectedConversationID == conversationID else { return }
        stats = TokenUsageStats.compute(messages: snapshot)
    }
}
