import Foundation
import KitLLM
import SwiftUI

/// 工具栏 chip：显示 MiniMax Token Plan 剩余量，点击弹出详情面板。
///
/// 样式与 ``VerbosityToolbarView`` / `AgentRulesChatToolbarView` 保持一致。
/// 首次拉取由 ``MiniMaxSelectionObserver`` 在选中 MiniMax 时触发，这里只在
/// 出现时补一次「TTL 已过期才拉」；定时器随 chip 出现 / 消失启停，
/// chip 不可见时不发请求。
struct TokenPlanToolbarView: View {
    @ObservedObject private var viewModel: TokenPlanViewModel

    @State private var isPopoverPresented = false
    @State private var poller: Timer?

    init(viewModel: TokenPlanViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        // revision 是本 View 唯一的刷新信号源：ViewModel 状态变化时自增，驱动 body 重算。
        let _ = viewModel.revision

        Group {
            if let text = viewModel.statusBarText {
                chip(text: text)
            } else {
                loadingChip
            }
        }
        .task { handleAppear() }
        .onDisappear { handleDisappear() }
    }
}

// MARK: - View

extension TokenPlanToolbarView {

    private func chip(text: String) -> some View {
        Button {
            isPopoverPresented.toggle()
        } label: {
            chipLabel(text: text)
        }
        .buttonStyle(.plain)
        .help(pluginLocalization.string("MiniMax Token Plan Quota"))
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            TokenPlanDetailView(status: viewModel.status, onRefresh: viewModel.refresh)
                .frame(width: 360)
        }
    }

    private func chipLabel(text: String) -> some View {
        HStack(spacing: TokenPlanToolbarMetrics.chipSpacing) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: TokenPlanToolbarMetrics.chipIconSize, weight: .medium))
            Text(text)
                .font(.system(size: TokenPlanToolbarMetrics.chipTextSize, weight: TokenPlanToolbarMetrics.chipTextWeight))
                .monospacedDigit()
        }
        .foregroundColor(.primary)
        .padding(.horizontal, TokenPlanToolbarMetrics.chipHorizontalPadding)
        .padding(.vertical, TokenPlanToolbarMetrics.chipVerticalPadding)
        .background(
            Color.secondary.opacity(0.15),
            in: RoundedRectangle(cornerRadius: TokenPlanToolbarMetrics.chipCornerRadius, style: .continuous)
        )
    }

    private var loadingChip: some View {
        chipLabel(text: pluginLocalization.string("Loading..."))
            .foregroundColor(.secondary)
            .help(pluginLocalization.string("MiniMax Token Plan Quota"))
    }
}

// MARK: - Event Handler

extension TokenPlanToolbarView {

    private func handleAppear() {
        viewModel.refreshIfNeeded()
        startPolling()
    }

    private func handleDisappear() {
        stopPolling()
        viewModel.cancelPendingFetch()
    }

    private func startPolling() {
        stopPolling()
        let viewModel = self.viewModel
        poller = Timer.scheduledTimer(
            withTimeInterval: TokenPlanToolbarMetrics.pollInterval,
            repeats: true
        ) { _ in
            Task { @MainActor in viewModel.refreshIfNeeded() }
        }
    }

    private func stopPolling() {
        poller?.invalidate()
        poller = nil
    }
}

// MARK: - Preview

#if DEBUG
/// 预览用固定配额数据：不触网、不读 Keychain。
@MainActor
private func makeToolbarPreviewViewModel() -> TokenPlanViewModel {
    let viewModel = TokenPlanViewModel(
        apiService: VendorAPIService(),
        apiKeyStorageKey: MiniMaxSharedConstants.apiKeyStorageKey
    )
    viewModel.previewStatus = .success(TokenPlanPreviewFixtures.allPlans)
    return viewModel
}

#Preview("Quota Loaded") {
    TokenPlanToolbarView(viewModel: makeToolbarPreviewViewModel())
        .inRootView()
}

#Preview("Quota Loading") {
    TokenPlanToolbarView(
        viewModel: TokenPlanViewModel(
            apiService: VendorAPIService(),
            apiKeyStorageKey: MiniMaxSharedConstants.apiKeyStorageKey
        )
    )
    .inRootView()
}
#endif
