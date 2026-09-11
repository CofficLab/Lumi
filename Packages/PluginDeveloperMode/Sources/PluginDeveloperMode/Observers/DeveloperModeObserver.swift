import Foundation
import ProviderDeveloperMode

/// 开发者模式外部状态 → ViewModel 的桥梁。
///
/// 初始化时接收 capability 与 viewModel，收到 `.enabledChanged` 事件后
/// 直接修改 ViewModel；不向外传回调，View 不创建 Observer。
@MainActor
final class DeveloperModeObserver {
    private let capability: any DeveloperModeCapability
    private let viewModel: DeveloperModeViewModel
    private var observerHandle: (any DeveloperModeProvidingObserverHandle)?

    init(capability: any DeveloperModeCapability, viewModel: DeveloperModeViewModel) {
        self.capability = capability
        self.viewModel = viewModel
        viewModel.update(isEnabled: capability.isEnabled)
        observerHandle = capability.addObserver { [weak self] event in
            guard let self else { return }
            switch event {
            case .enabledChanged(let value):
                self.viewModel.update(isEnabled: value)
            }
        }
    }

    func cancel() {
        observerHandle?.cancel()
        observerHandle = nil
    }
}
