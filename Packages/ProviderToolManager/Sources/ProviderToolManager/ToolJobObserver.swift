import Foundation

@MainActor
public protocol ToolJobObserverHandle: AnyObject {
    func cancel()
}

@MainActor
private final class NoopToolJobObserverHandle: ToolJobObserverHandle {
    func cancel() {}
}

public extension ToolManagerProviding {
    /// 注册 Job 生命周期观察者。
    ///
    /// 默认实现为空，保证尚未迁移到 Job 执行模型的 ToolManager 仍然兼容。
    @discardableResult
    func addToolJobObserver(
        _ callback: @escaping (ToolJobEvent) -> Void
    ) -> any ToolJobObserverHandle {
        _ = callback
        return NoopToolJobObserverHandle()
    }
}
