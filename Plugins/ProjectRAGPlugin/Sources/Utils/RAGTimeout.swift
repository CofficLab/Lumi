import Foundation

/// 带超时的异步操作结果
public enum RAGTimeoutResult<T: Sendable>: Sendable {
    case success(T)
    case timedOut
}

/// RAG 超时工具
public enum RAGTimeout {
    private final class ResumeState<T: Sendable>: @unchecked Sendable {
        private let lock = NSLock()
        private var didResume = false

        func resume(
            _ result: RAGTimeoutResult<T>,
            continuation: CheckedContinuation<RAGTimeoutResult<T>, Never>
        ) -> Bool {
            lock.lock()
            guard !didResume else {
                lock.unlock()
                return false
            }
            didResume = true
            lock.unlock()
            continuation.resume(returning: result)
            return true
        }
    }

    private final class TaskBox: @unchecked Sendable {
        private let lock = NSLock()
        private var operationTask: Task<Void, Never>?
        private var timeoutTask: Task<Void, Never>?

        func setOperationTask(_ task: Task<Void, Never>) {
            lock.lock()
            operationTask = task
            lock.unlock()
        }

        func setTimeoutTask(_ task: Task<Void, Never>) {
            lock.lock()
            timeoutTask = task
            lock.unlock()
        }

        func cancelOperationTask() {
            lock.lock()
            let task = operationTask
            lock.unlock()
            task?.cancel()
        }

        func cancelTimeoutTask() {
            lock.lock()
            let task = timeoutTask
            lock.unlock()
            task?.cancel()
        }
    }

    /// 带超时的 await 包装，超时返回 .timedOut 而非挂起
    ///
    /// - Parameters:
    ///   - seconds: 超时秒数，必须 > 0
    ///   - operation: 异步操作闭包
    /// - Returns: 操作成功返回 .success，超时返回 .timedOut
    public static func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @escaping @Sendable () async -> T
    ) async -> RAGTimeoutResult<T> {
        guard seconds > 0 else { return .timedOut }
        return await withCheckedContinuation { continuation in
            let state = ResumeState<T>()
            let taskBox = TaskBox()

            let operationTask = Task {
                let value = await operation()
                if state.resume(.success(value), continuation: continuation) {
                    taskBox.cancelTimeoutTask()
                }
            }
            taskBox.setOperationTask(operationTask)

            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                taskBox.cancelOperationTask()
                _ = state.resume(.timedOut, continuation: continuation)
            }
            taskBox.setTimeoutTask(timeoutTask)
        }
    }
}
