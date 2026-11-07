import Combine

@MainActor
public final class MenuBarRefreshModel: ObservableObject {
    @Published public private(set) var revision = 0

    private let provider: any MenuBarProviding
    private var observer: (any MenuBarObserverHandle)?

    public init(provider: any MenuBarProviding) {
        self.provider = provider
        resume()
    }

    public func resume() {
        guard observer == nil else { return }
        observer = provider.addMenuBarObserver { [weak self] _ in
            self?.revision &+= 1
        }
    }

    public func cancel() {
        observer?.cancel()
        observer = nil
    }
}
