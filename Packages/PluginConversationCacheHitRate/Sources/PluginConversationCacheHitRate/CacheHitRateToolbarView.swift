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
    @State private var latestSnapshot: [Message] = []
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
            .frame(width: 420)
        }
        .onChange(of: selectedConversationID) { newValue in
            if newValue == nil {
                isPopoverPresented = false
            }
        }
        .onChange(of: isPopoverPresented) { presented in
            // 打开弹窗时用最近快照即时补建历史，关闭时清空（#1226）。
            history = CacheHitRateHistoryGate.resolve(
                isPopoverPresented: presented,
                snapshot: latestSnapshot
            )
        }
        .task(id: "\(selectedConversationID?.uuidString ?? "nil")-\(messageRefreshRevision)") {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            await refresh(revision: messageRefreshRevision)
        }
        .onAppear {
            guard observerHandle == nil else { return }
            selectedConversationID = state.selectedConversationID
            observerHandle = state.addObserver { event in
                switch event {
                case let .selectedConversationChanged(id):
                    selectedConversationID = id
                    // 选择一变就立即清空展示态，避免 debounce + 读盘期间把上一会话的数据当作新会话（#599）。
                    let reset = CacheHitRateSelectionGate.reset(forConversationID: id)
                    stats = reset.stats
                    history = reset.history
                    latestSnapshot = []
                    unavailabilityReason = reset.unavailabilityReason
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
            return String(format: pluginLocalization.string("Token-weighted cache hit rate: %@ (%lld requests)"), stats.percentText, stats.sampleCount)
        }
        return pluginLocalization.string("Cache hit rate unavailable: click for details")
    }

    private func refresh(revision: Int) async {
        guard let conversationID = selectedConversationID else {
            stats = .empty
            history = .empty
            latestSnapshot = []
            unavailabilityReason = .noConversationSelected
            return
        }
        let snapshot = await messages.messagesSnapshot(in: conversationID)
        guard CacheHitRateRefreshGate.shouldPublish(
            revision: revision,
            currentRevision: messageRefreshRevision,
            conversationID: conversationID,
            selectedConversationID: selectedConversationID,
            isCancelled: Task.isCancelled
        ) else { return }
        latestSnapshot = snapshot
        stats = CacheHitRateStats.compute(messages: snapshot)
        // 历史只在弹窗打开时构建；关闭时跳过排序 / 遍历（#1226）。
        history = CacheHitRateHistoryGate.resolve(
            isPopoverPresented: isPopoverPresented,
            snapshot: snapshot
        )
        if stats.sampleCount > 0 {
            unavailabilityReason = .waitingForResponse
        } else if snapshot.contains(where: { $0.role == .assistant }) {
            unavailabilityReason = .providerDidNotReportUsage
        } else {
            unavailabilityReason = .waitingForResponse
        }
    }
}

/// 快照 `await` 返回后的发布门禁。
///
/// `messagesSnapshot` 内部用 detached 任务读盘，取消外层 SwiftUI 任务不会终止它，
/// 已取消/被新 revision 取代的刷新仍能走到发布这一步；必须同时校验取消状态与
/// 刷新代次，否则旧快照会覆盖同会话的新统计（#998）。
enum CacheHitRateRefreshGate {
    static func shouldPublish(
        revision: Int,
        currentRevision: Int,
        conversationID: UUID,
        selectedConversationID: UUID?,
        isCancelled: Bool
    ) -> Bool {
        guard !isCancelled else { return false }
        guard conversationID == selectedConversationID else { return false }
        return revision == currentRevision
    }
}

/// 趋势历史构建门禁（#1226）。
///
/// 工具栏数值（`CacheHitRateStats`）常驻可见、必须即时刷新；趋势历史只在弹窗里
/// 展示。`CacheHitRateHistory.build` 会对整段消息排序并逐条累计（O(M log M)），
/// 长会话里每条消息插入都重建会造成主线程卡顿。弹窗关闭时直接返回空历史，
/// 打开时用最近一次快照即时补建，无需等待新的刷新事件。
enum CacheHitRateHistoryGate {
    static func resolve(isPopoverPresented: Bool, snapshot: [Message]) -> CacheHitRateHistory {
        isPopoverPresented ? CacheHitRateHistory.build(from: snapshot) : .empty
    }
}

/// 切换选中会话时的即时清空门禁（#599）。
///
/// 选择变化到新会话快照返回之间隔着 150ms debounce 与异步读盘。此前 observer 只
/// 更新 `selectedConversationID`，不清空展示态，于是上一会话的命中率、历史与不可用
/// 原因在这段时间里被当作新会话的数据展示。选择一变就立即归零：选中新会话显示等待态，
/// 无会话显示未选择态，旧统计绝不会被归到新会话名下。
enum CacheHitRateSelectionGate {
    struct Reset: Equatable {
        let stats: CacheHitRateStats
        let history: CacheHitRateHistory
        let unavailabilityReason: CacheHitRateUnavailability
    }

    static func reset(forConversationID id: UUID?) -> Reset {
        Reset(
            stats: .empty,
            history: .empty,
            unavailabilityReason: id == nil ? .noConversationSelected : .waitingForResponse
        )
    }
}
