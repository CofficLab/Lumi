import ProviderConversation
import ProviderMessage
import SwiftUI

/// 缓存命中率工具栏视图。
struct CacheHitRateToolbarView: View {
    let messages: any MessageManaging
    let state: CacheHitRateToolbarState

    @State private var stats = CacheHitRateStats.empty
    @State private var history = CacheHitRateHistory.empty
    @State private var unavailabilityReason: CacheHitRateUnavailability = .noConversationSelected
    @State private var isPopoverPresented = false
    @State private var selectedConversationID: UUID?
    @State private var messageRefreshRevision = 0
    @State private var observerHandle: (any CacheHitRateToolbarState.ObserverHandle)?

    var body: some View {
        Button {
            isPopoverPresented.toggle()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "memorychip")
                    .font(.system(size: 10, weight: .medium))
                Text(rateLabel)
                    .font(.system(size: 10, weight: .medium))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .foregroundColor(stats.sampleCount > 0 ? percentColor : .secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                stats.sampleCount > 0
                    ? Color.secondary.opacity(0.15)
                    : Color.secondary.opacity(0.12),
                in: RoundedRectangle(cornerRadius: 5, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(helpText)
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            CacheHitRatePopover(
                stats: stats,
                history: history,
                unavailabilityReason: unavailabilityReason
            )
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
                case .messagesChanged:
                    messageRefreshRevision &+= 1
                }
            }
        }
        .onDisappear {
            observerHandle?.cancel()
            observerHandle = nil
        }
    }

    private var percentColor: Color {
        switch stats.weightedHitRate {
        case 0.7...: return .green.opacity(0.85)
        case 0.4..<0.7: return .orange.opacity(0.9)
        default: return .red.opacity(0.85)
        }
    }

    private var rateLabel: String {
        stats.sampleCount > 0 ? stats.percentText : "—"
    }

    private var helpText: String {
        if stats.sampleCount > 0 {
            return String(format: LumiPluginLocalization.string("Token-weighted cache hit rate: %@ (%lld requests)", bundle: .module), stats.percentText, stats.sampleCount)
        }
        return LumiPluginLocalization.string("Cache hit rate unavailable: click for details", bundle: .module)
    }

    private func refresh() async {
        guard let conversationID = selectedConversationID else {
            stats = .empty
            history = .empty
            unavailabilityReason = .noConversationSelected
            return
        }
        let snapshot = await messages.messagesSnapshot(in: conversationID)
        guard conversationID == selectedConversationID else { return }
        stats = CacheHitRateStats.compute(messages: snapshot)
        history = CacheHitRateHistory.build(from: snapshot)
        if stats.sampleCount > 0 {
            unavailabilityReason = .waitingForResponse
        } else if snapshot.contains(where: { $0.role == .assistant }) {
            unavailabilityReason = .providerDidNotReportUsage
        } else {
            unavailabilityReason = .waitingForResponse
        }
    }
}
