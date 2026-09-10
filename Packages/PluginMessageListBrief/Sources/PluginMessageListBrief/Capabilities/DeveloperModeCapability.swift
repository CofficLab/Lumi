import ProviderDeveloperMode

/// 消息行开发者标记所需的最小能力。
@MainActor
protocol MessageListDeveloperModeCapability: AnyObject {
    var isEnabled: Bool { get }

    @discardableResult
    func addObserver(
        _ callback: @escaping (DeveloperModeProvidingEvent) -> Void
    ) -> any DeveloperModeProvidingObserverHandle
}

@MainActor
final class MessageListDeveloperModeCapabilityAdapter: MessageListDeveloperModeCapability {
    private let developerMode: any DeveloperModeProviding

    init(developerMode: any DeveloperModeProviding) {
        self.developerMode = developerMode
    }

    var isEnabled: Bool { developerMode.isEnabled }

    @discardableResult
    func addObserver(
        _ callback: @escaping (DeveloperModeProvidingEvent) -> Void
    ) -> any DeveloperModeProvidingObserverHandle {
        developerMode.addObserver(callback)
    }
}
