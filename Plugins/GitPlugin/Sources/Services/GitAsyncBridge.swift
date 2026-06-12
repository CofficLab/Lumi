import Foundation

/// 将 DispatchQueue 上的同步工作桥接到 async/await。
///
/// continuation 必须在工作队列之外 resume，否则 resume 会同步运行等待方 Task，
/// 若该 Task 再抛错会被外层 catch 捕获并二次 resume，触发 EXC_BREAKPOINT 崩溃。
enum GitAsyncBridge {
    static func perform<T: Sendable>(
        on queue: DispatchQueue,
        body: @escaping @Sendable () throws -> T
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            let guardBox = ContinuationGuard(continuation)
            queue.async {
                let result: Result<T, Error>
                do {
                    result = .success(try body())
                } catch {
                    result = .failure(error)
                }
                DispatchQueue.global(qos: .userInitiated).async {
                    guardBox.complete(with: result)
                }
            }
        }
    }
}

final class ContinuationGuard<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, Error>?

    init(_ continuation: CheckedContinuation<T, Error>) {
        self.continuation = continuation
    }

    func complete(with result: Result<T, Error>) {
        lock.lock()
        guard let continuation else {
            lock.unlock()
            return
        }
        self.continuation = nil
        lock.unlock()
        continuation.resume(with: result)
    }
}
