import Foundation

/// `LLMManaging` 默认观察句柄：持有取消闭包，供各实现复用。
@MainActor
public final class DefaultLLMManagerObserverHandle: LLMManagerObserverHandle {
    private var cancellation: (() -> Void)?

    public init(cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }

    public func cancel() {
        cancellation?()
        cancellation = nil
    }
}