import Foundation
import ProviderProjectRAG

/// 收敛 ProjectRAGProviding 的最小操作，供 ViewModel/Observer 使用。
@MainActor
final class ProjectRAGStatusCapability {
    private let providerResolver: @MainActor () -> (any ProjectRAGProviding)?

    init(providerResolver: @escaping @MainActor () -> (any ProjectRAGProviding)?) {
        self.providerResolver = providerResolver
    }

    var provider: (any ProjectRAGProviding)? {
        providerResolver()
    }

    @discardableResult
    func addObserver(_ callback: @escaping (ProjectRAGEvent) -> Void) -> (any ProjectRAGObserverHandle)? {
        provider?.addProjectRAGObserver(callback)
    }
}
