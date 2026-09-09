import ProviderDeveloperMode

/// 将开发者模式变化转发为消息列表 ViewModel 状态。
@MainActor
final class DeveloperModeObserver {
    private var handle: (any DeveloperModeProvidingObserverHandle)?

    init(
        developerMode: any MessageListDeveloperModeCapability,
        viewModel: ListV1ViewModel
    ) {
        viewModel.updateDeveloperMode(enabled: developerMode.isEnabled)
        handle = developerMode.addObserver { [weak viewModel] event in
            guard case let .enabledChanged(enabled) = event else { return }
            viewModel?.updateDeveloperMode(enabled: enabled)
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
