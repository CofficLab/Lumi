import Foundation

/// 单次工具调用的取消上下文。
///
/// 和 Swift `Task.cancel()` 不同，这个上下文会显式传入工具内部，让工具可以把取消
/// 转发给底层资源（如 `Process.terminate()`、`WKWebView.stopLoading()` 或外部 SDK）。
final class ToolExecutionContext: @unchecked Sendable {
    typealias CancellationHandler = @Sendable () -> Void

    let conversationId: UUID
    let toolCallId: String
    let toolName: String

    private let lock = NSLock()
    private var cancelled = false
    private var handlers: [UUID: CancellationHandler] = [:]

    init(conversationId: UUID, toolCallId: String, toolName: String) {
        self.conversationId = conversationId
        self.toolCallId = toolCallId
        self.toolName = toolName
    }

    var isCancelled: Bool {
        lock.lock()
        let value = cancelled
        lock.unlock()
        return value || Task.isCancelled
    }

    func checkCancellation() throws {
        if isCancelled {
            throw CancellationError()
        }
    }

    @discardableResult
    func onCancel(_ handler: @escaping CancellationHandler) -> UUID? {
        lock.lock()
        if cancelled {
            lock.unlock()
            handler()
            return nil
        }
        let id = UUID()
        handlers[id] = handler
        lock.unlock()
        return id
    }

    func removeCancellationHandler(_ id: UUID?) {
        guard let id else { return }
        lock.lock()
        handlers[id] = nil
        lock.unlock()
    }

    func cancel() {
        let handlersToRun: [CancellationHandler]
        lock.lock()
        guard !cancelled else {
            lock.unlock()
            return
        }
        cancelled = true
        handlersToRun = Array(handlers.values)
        handlers.removeAll()
        lock.unlock()

        for handler in handlersToRun {
            handler()
        }
    }
}
