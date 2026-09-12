import Foundation
import ProviderDeveloperMode

/// 开发者模式插件需要的最小能力。
@MainActor
protocol DeveloperModeCapability: AnyObject {
    var isEnabled: Bool { get }
    func toggle()
    func addObserver(_ callback: @escaping (DeveloperModeProvidingEvent) -> Void) -> any DeveloperModeProvidingObserverHandle
}

/// 将内核 DeveloperModeProviding 收窄为插件能力。
@MainActor
final class DeveloperModeCapabilityAdapter: DeveloperModeCapability {
    private weak var provider: (any DeveloperModeProviding)?

    init(provider: any DeveloperModeProviding) {
        self.provider = provider
    }

    var isEnabled: Bool {
        provider?.isEnabled ?? false
    }

    func toggle() {
        provider?.toggle()
    }

    func addObserver(_ callback: @escaping (DeveloperModeProvidingEvent) -> Void) -> any DeveloperModeProvidingObserverHandle {
        provider?.addObserver(callback) ?? NoopDeveloperModeProvidingObserverHandle()
    }
}
