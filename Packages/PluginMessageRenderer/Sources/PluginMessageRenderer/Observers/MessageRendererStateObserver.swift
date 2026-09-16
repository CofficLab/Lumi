import Foundation
import ProviderDeveloperMode

/// 开发者模式外部状态 → 共享 ViewModel 的桥梁。
///
/// 在插件组装层创建，收到 `.enabledChanged` 事件后直接修改
/// `MessageRendererStateViewModel`；不向外传回调，View 不创建 Observer。
@MainActor
final class MessageRendererStateObserver {
    private let capability: any MessageRendererCapability
    private let viewModel: MessageRendererStateViewModel
    private var observerHandle: (any DeveloperModeProvidingObserverHandle)?

    init(
        capability: any MessageRendererCapability,
        viewModel: MessageRendererStateViewModel
    ) {
        self.capability = capability
        self.viewModel = viewModel
        viewModel.update(isDeveloperModeEnabled: capability.isDeveloperModeEnabled)
        observerHandle = capability.addDeveloperModeObserver { [weak self] event in
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
