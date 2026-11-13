import ProviderMessage
import SwiftUI

/// header 栏右侧的模型用时指示器。
///
/// 展示当前对话的**总**模型工作时间；点击后弹出 popover 拆分等待 / 生成时长。
struct ElapsedTimeHeaderView: View {
    let messages: any MessageManaging
    let state: ElapsedTimeToolbarState

    @State private var stats = ElapsedTimeStats.empty
    @State private var isPopoverPresented = false
    @State private var selectedConversationID: UUID?
    @State private var messageRefreshRevision = 0
    @State private var observerHandle: (any ElapsedTimeToolbarState.ObserverHandle)?

    var body: some View {
        Button {
            isPopoverPresented.toggle()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "timer")
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
            ElapsedTimePopover(stats: stats)
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

    /// 总用时的紧凑写法。
    private var totalLabel: String {
        guard !stats.isEmpty else { return "—" }
        return ElapsedTimeFormatter.compact(stats.totalSeconds)
    }

    private var helpText: String {
        guard !stats.isEmpty else {
            return pluginLocalization.string("Elapsed time unavailable: click for details")
        }
        return String(
            format: pluginLocalization.string("Total LLM time: %@ (%lld requests)"),
            ElapsedTimeFormatter.compact(stats.totalSeconds),
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
        stats = ElapsedTimeStats.compute(messages: snapshot)
    }
}
