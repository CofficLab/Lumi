import ProviderDeveloperMode

/// 消息行开发者标记所需的最小能力。
@MainActor
public protocol MessageListDeveloperModeCapability: AnyObject {
    var isEnabled: Bool { get }

    @discardableResult
    func addObserver(
        _ callback: @escaping (DeveloperModeProvidingEvent) -> Void
    ) -> any DeveloperModeProvidingObserverHandle
}

@MainActor
public final class MessageListDeveloperModeCapabilityAdapter: MessageListDeveloperModeCapability {
    private let developerMode: any DeveloperModeProviding

    public init(developerMode: any DeveloperModeProviding) {
        self.developerMode = developerMode
    }

    public var isEnabled: Bool { developerMode.isEnabled }

    @discardableResult
    public func addObserver(
        _ callback: @escaping (DeveloperModeProvidingEvent) -> Void
    ) -> any DeveloperModeProvidingObserverHandle {
        developerMode.addObserver(callback)
    }
}
