import Foundation
import ProviderDeveloperMode

/// 开发者模式外部状态 → 共享 ViewModel 的桥梁。
///
/// 在插件组装层创建，收到 `.enabledChanged` 事件后直接修改
/// `DeveloperModeStateViewModel`；不向外传回调，View 不创建 Observer。
@MainActor
final class DeveloperModeStateObserver {
    private let viewModel: DeveloperModeStateViewModel
    private var observerHandle: (any DeveloperModeProvidingObserverHandle)?

    init(
        provider: (any DeveloperModeProviding)?,
        viewModel: DeveloperModeStateViewModel
    ) {
        self.viewModel = viewModel
        viewModel.update(isDeveloperModeEnabled: provider?.isEnabled ?? false)
        observerHandle = provider?.addObserver { [weak self] event in
            guard let self else { return }
            switch event {
            case .enabledChanged(let value):
                self.viewModel.update(isDeveloperModeEnabled: value)
            }
        }
    }

    func cancel() {
        observerHandle?.cancel()
        observerHandle = nil
    }
}
