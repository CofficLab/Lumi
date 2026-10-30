import Foundation

/// Typed change channel for clipboard history mutations within this plugin.
@MainActor
final class ClipboardHistoryChangeCenter {
    static let shared = ClipboardHistoryChangeCenter()

    private var callbacks: [UUID: () -> Void] = [:]

    @discardableResult
    func addObserver(_ callback: @escaping () -> Void) -> ClipboardHistoryChangeToken {
        let id = UUID()
        callbacks[id] = callback
        return ClipboardHistoryChangeToken { [weak self] in
            self?.callbacks[id] = nil
        }
    }

    func notify() {
        callbacks.values.forEach { $0() }
    }

    /// 清空所有观察者。
    ///
    /// - Important: `shared` 是进程级单例，观察者注册表会跨用例残留。
    ///   单元测试触碰本单例后必须清理，否则后注册的回调会收到**前一个用例**
    ///   留下的通知，计数断言随之漂移——这类失败极难归因。
    ///   契约：测试在触碰 `shared` 前后各清理一次。
    func removeAllObservers() {
        callbacks.removeAll()
    }
}

@MainActor
final class ClipboardHistoryChangeToken {
    private var cancellation: (() -> Void)?

    init(cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }

    func cancel() {
        cancellation?()
        cancellation = nil
    }

}

/// Observes clipboard-history broadcasts and asks the view model to refresh.
@MainActor
final class ClipboardHistoryObserver {
    private var token: ClipboardHistoryChangeToken?

    init(onChange: @escaping () -> Void) {
        token = ClipboardHistoryChangeCenter.shared.addObserver(onChange)
    }

    func cancel() {
        token?.cancel()
        token = nil
    }
}
