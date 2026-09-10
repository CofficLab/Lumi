import ProviderDeveloperMode

/// 将开发者模式变化转发为当前对话消息列表 VM 状态。
@MainActor
final class DeveloperModeObserver {
    private var handle: (any DeveloperModeProvidingObserverHandle)?

    init(
        developerMode: any MessageListDeveloperModeCapability,
        vm: ConversationMessageListVM
    ) {
        vm.updateDeveloperMode(enabled: developerMode.isEnabled)
        handle = developerMode.addObserver { [weak vm] event in
            guard case let .enabledChanged(enabled) = event else { return }
            vm?.updateDeveloperMode(enabled: enabled)
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
