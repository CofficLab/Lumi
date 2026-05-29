import Foundation

/// 带超时的异步操作结果
public enum RAGTimeoutResult<T: Sendable>: Sendable {
    case success(T)
    case timedOut
}

/// RAG 超时工具
public enum RAGTimeout {
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
            let task = Task {
                await operation()
            }

            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                task.cancel()
            }

            Task {
                let value = await task.value
                timeoutTask.cancel()
                continuation.resume(returning: .success(value))
            }
        }
    }
}
