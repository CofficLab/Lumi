import Foundation

/// 全局 libgit2 访问串行化协调器。
///
/// libgit2 的 `git_repository` / `git_index` 等对象不是线程安全的，
/// 并发打开同一仓库或并发读取 index 可能导致 C 层内存错误（`EXC_BAD_ACCESS`），
/// 这种内存破坏又会以"延迟崩溃"的形式在协作线程池上暴露为
/// `EXC_BREAKPOINT` / `completeTaskWithClosure+1`，极难定位。
///
/// Lumi 中有多个插件（`GitPlugin`、`EditorFileTreeV2Plugin`、`EditorFileTreePlugin`）
/// 都会调用 LibGit2Swift。历史上每个插件各自直接调 `LibGit2.*`，彼此之间没有互斥，
/// 于是文件树的后台状态刷新与 Git 插件的 git 工具调用会同时进入 libgit2。
///
/// 本类型提供一个**进程级单一串行队列**作为所有 libgit2 调用的总入口，
/// 把多入口的并发压缩成串行执行，从根上消除跨插件的 libgit2 数据竞争。
///
/// - Note: 队列 QoS 用 `.userInitiated`，与历史 `GitService.gitQueue` 一致，
///   保证用户可见的 git 操作（提交、状态查询）依然高优先级、不拖慢 UI。
public enum GitAccessCoordinator {
    /// 保护所有 libgit2 调用的单一串行队列。
    ///
    /// 用 `static let` 保证全进程唯一；所有插件共享同一个实例。
    public static let queue: DispatchQueue = DispatchQueue(
        label: "com.lumi.libgit2.global",
        qos: .userInitiated
    )

    /// 在共享串行队列上执行一个同步工作块，并把结果以 async 形式返回。
    ///
    /// 这是把 GCD 串行队列桥接到 async/await 的标准用法：
    /// `withCheckedThrowingContinuation` 的 `resume` 在 `queue.async` 块尾部直接调用，
    /// 结果会被协作线程池接管，等待方不会在本 GCD 块内同步执行，
    /// 因此既不会重入死锁，也不会触发 `SWIFT TASK CONTINUATION MISUSE`。
    ///
    /// - Parameter body: 在串行队列上执行的同步工作。必须是 `@Sendable`。
    /// - Returns: 工作块返回的值。
    /// - Throws: 工作块抛出的任何错误。
    public static func perform<T: Sendable>(
        _ body: @escaping @Sendable () throws -> T
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
                guardBox.complete(with: result)
            }
        }
    }

    /// 在共享串行队列上同步执行一个工作块。
    ///
    /// 供那些无法改成 async 的调用方（例如 SwiftUI 视图的同步属性 getter、
    /// 或被 `MainActor` 同步调用的方法）使用。调用方需自行确保**不会**从
    /// `perform(_:)` 的等待方上下文再次调用本方法，否则会死锁串行队列。
    ///
    /// - Important: 不要在 `queue` 自身的执行上下文里调用本方法（串行队列
    ///   自等待会死锁）。若已确定在后台上下文，优先用 async 版本。
    public static func performSync<T>(_ body: @Sendable () throws -> T) rethrows -> T {
        try queue.sync(execute: body)
    }
}

/// 防御性包装：保证一个 continuation 至多被 resume 一次。
///
/// 即使工作块因 bug 触发两次完成，或某条异常路径与正常路径同时尝试 resume，
/// 这里也能吞掉后续的重复 resume，避免
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