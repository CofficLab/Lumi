import Foundation

/// 将串行 `DispatchQueue` 上的同步工作桥接到 async/await。
///
/// ## 历史
///
/// 旧实现把 continuation 的 resume 放进一个独立的
/// `DispatchQueue.global(qos: .userInitiated).async { }` 块里执行（"避免在工作队列内
/// resume 导致重入"）。这个多余的 GCD 跳转触发了生产环境持续崩溃：
/// 在 `queue='com.apple.root.user-initiated-qos.cooperative'` 上抛出
/// `EXC_BREAKPOINT`，故障帧固定落在
/// `completeTaskWithClosure(...) +1`（BRK #0xC473，Swift 并发运行时的
/// `SWIFT TASK CONTINUATION MISUSE` 陷阱）。因为 resume 发生在 GCD 线程而非协作线程池
/// 的工作线程上，运行时在该线程读不到正确的 task-local 状态（栈里可见
/// `pthread_self → _NSThreadGet0`），于是在 Release 构建下随机陷阱。
///
/// ## 修复
///
/// 直接在 `queue.async` 块尾部 resume continuation —— 这是 `withCheckedThrowingContinuation`
/// 文档支持的标准用法。`resume(with:)` 本身只会把结果投递回等待方所在的协作线程池，
/// **不会**同步执行等待方代码（旧注释里"resume 会同步运行等待方 Task"是误判），因此
/// 不存在所谓"工作队列内 resume 引发重入"的问题。
///
/// 仍保留 `ContinuationGuard` 做防御性去重（历史上确实修过一次真正的 double-resume，
/// 见 commit f8d9849c4），但 resume 不再经过额外的 GCD hop。
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
                // 直接 resume：结果会被协作线程池接管，等待方不会在本 GCD 块内同步执行。
                guardBox.complete(with: result)
            }
        }
    }
}

/// 防御性包装：保证一个 continuation 至多被 resume 一次。
///
/// 即使 `perform` 的调用方因 bug 把同一个闭包触发两次，或 body 与某条异常路径
/// 同时尝试完成，这里也能吞掉后续的重复 resume，避免
/// `SWIFT TASK CONTINUATION MISUSE`（resume twice）陷阱。
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
