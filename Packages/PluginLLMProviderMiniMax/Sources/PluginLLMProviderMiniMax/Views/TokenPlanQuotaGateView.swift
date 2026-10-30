import Foundation
import KitLLM
import SwiftUI

/// 工具栏配额 chip 的可见性门控。
///
/// chip 本身由 ``TokenPlanToolbarView`` 渲染；本视图只把「当前是否选中
/// MiniMax」这一布尔量翻译成「渲染 chip 还是空视图」，让门控行为在视图层
/// 可直接断言。
struct TokenPlanQuotaGateView: View {
    @ObservedObject private var gate: MiniMaxSelectionGate

    private let viewModel: TokenPlanViewModel

    init(gate: MiniMaxSelectionGate, viewModel: TokenPlanViewModel) {
        self.gate = gate
        self.viewModel = viewModel
    }

    var body: some View {
        if gate.isEnabled {
            TokenPlanToolbarView(viewModel: viewModel)
        }
    }
}

// MARK: - Preview

#if DEBUG
/// 预览用固定配额数据：不触网、不读 Keychain。
@MainActor
private func makeGatePreviewViewModel() -> TokenPlanViewModel {
    let viewModel = TokenPlanViewModel(
        apiService: VendorAPIService(),
        apiKeyStorageKey: MiniMaxSharedConstants.apiKeyStorageKey
    )
    viewModel.previewStatus = .success([TokenPlanPreviewFixtures.generalPlan])
    return viewModel
}

@MainActor
private func makeGatePreview(_ enabled: Bool) -> TokenPlanQuotaGateView {
    TokenPlanQuotaGateView(
        gate: MiniMaxSelectionGate(isEnabled: enabled),
        viewModel: makeGatePreviewViewModel()
    )
}

#Preview("Gate Disabled") {
    makeGatePreview(false)
        .inRootView()
}

#Preview("Gate Enabled") {
    makeGatePreview(true)
        .inRootView()
}
#endif
