import ProviderConversation
import ProviderMessage
import SwiftUI

/// 缓存命中率工具栏视图。
struct CacheHitRateToolbarView: View {
    let messages: any MessageManaging
    let state: CacheHitRateToolbarState

    @State private var stats = CacheHitRateStats.empty
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
            CacheHitRatePopover(stats: stats, unavailabilityReason: unavailabilityReason)
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
            unavailabilityReason = .noConversationSelected
            return
        }
        let snapshot = await messages.messagesSnapshot(in: conversationID)
        guard conversationID == selectedConversationID else { return }
        stats = CacheHitRateStats.compute(messages: snapshot)
        if stats.sampleCount > 0 {
            unavailabilityReason = .waitingForResponse
        } else if snapshot.contains(where: { $0.role == .assistant }) {
            unavailabilityReason = .providerDidNotReportUsage
        } else {
            unavailabilityReason = .waitingForResponse
        }
    }
}

private struct CacheHitRatePopover: View {
    let stats: CacheHitRateStats
    let unavailabilityReason: CacheHitRateUnavailability

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "memorychip")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                Text(LumiPluginLocalization.string("Cache Hit Rate", bundle: .module))
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            if stats.sampleCount > 0 {
                Text(stats.precisePercentText)
                    .font(.system(size: 34, weight: .bold))
                    .monospacedDigit()
                    .foregroundColor(hitRateColor)

                Text(String(format: LumiPluginLocalization.string("%lld requests in this conversation", bundle: .module), stats.sampleCount))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                unavailableBlock
            }

            if stats.sampleCount > 0 {
                Divider()

                statRow(
                    icon: "arrow.down.circle",
                    label: LumiPluginLocalization.string("Cached tokens", bundle: .module),
                    value: stats.totalCachedTokens.formatted(.number.grouping(.automatic))
                )
                statRow(
                    icon: "arrow.up.circle",
                    label: LumiPluginLocalization.string("Total input tokens", bundle: .module),
                    value: stats.totalInputTokens.formatted(.number.grouping(.automatic))
                )
                statRow(
                    icon: "scalemass",
                    label: LumiPluginLocalization.string("Token-weighted rate", bundle: .module),
                    value: String(format: "%.1f%%", stats.weightedHitRate * 100)
                )
                statRow(
                    icon: "chart.bar",
                    label: LumiPluginLocalization.string("Per-request average", bundle: .module),
                    value: String(format: "%.1f%%", stats.averageHitRate * 100)
                )

                Divider()

                Text("命中率 = 缓存读取 tokens ÷ 总输入 tokens。该数值按 token 加权，缓存命中越高，重复上下文计费越低、响应越快。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .frame(width: 280)
    }

    private var unavailableBlock: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(LumiPluginLocalization.string("Cache hit rate unavailable", bundle: .module))
                    .font(.subheadline.weight(.semibold))
                Text(unavailabilityReason.localizedExplanation)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var hitRateColor: Color {
        switch stats.weightedHitRate {
        case 0.7...: return .green.opacity(0.9)
        case 0.4..<0.7: return .orange.opacity(0.95)
        default: return .red.opacity(0.9)
        }
    }

    private func statRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 16)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
    }
}
