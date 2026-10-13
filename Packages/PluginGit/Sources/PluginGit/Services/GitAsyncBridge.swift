import Foundation

/// 将串行 Git 工作安全地桥接到 async/await。
///
/// ## 线程模型
///
/// - **串行化按队列身份划分**：同一个 `DispatchQueue` 参数上的 body 严格串行，
///   不同队列并行执行。`GitAccessCoordinator.queue(for:)` 为每个仓库根维护一条
///   队列，因此单个仓库的慢调用 / 卡死调用不会拖住其它仓库的 Git 操作。
/// - **body 不在传入队列的线程上执行**，而在后台任务中执行；队列仅作为串行
///   分组的身份使用。这保证 body 内部再对该队列调用 `sync` 也不会自我死锁
///   （旧实现在队列线程上执行 body，重入 `queue.sync` 即永久死锁整个通道）。
/// - **等待有界**：`timeout` 覆盖「排队 + 执行」全过程，超时抛
///   ``GitAsyncBridgeError/timeout``；任务取消立即抛 `CancellationError`。
///   两种放弃情形下，body 若尚未开始则直接跳过不执行；若已在执行则无法中断
///   （libgit2 C 调用不可打断），会继续执行到自然结束并释放串行权。
///
/// ## 历史
///
/// 旧实现把 continuation 的 resume 放进一个独立的
/// `DispatchQueue.global(qos: .userInitiated).async { }` 块里执行（"避免在工作队列内
/// resume 导致重入"）。这个多余的 GCD 跳转触发了生产环境持续崩溃：
/// 在 `queue='com.apple.root.user-initiated-qos.cooperative'` 上抛出
/// `EXC_BREAKPOINT`，故障帧固定落在
/// `completeTaskWithClosure(...) +1`（BRK #0xC473，Swift 并发运行时的
/// `SWIFT TASK CONTINUATION MISUSE` 陷阱），根因是一次真正的 double-resume
/// （见 commit f8d9849c4）。`ContinuationGuard` 保留至今做防御性去重。
///
/// 更早的版本没有超时与取消支持：一次卡死的 libgit2 调用会占住全局串行队列，
/// 所有会话的 Git 工具无限排队（表现为"多个对话一直等待中"）。本次重构按
/// 仓库根隔离串行域，并为等待加上超时与取消。
enum GitAsyncBridge {
    /// 单次 Git 操作的默认超时（含排队等待）。超时后向调用方抛错，不再无限等待。
    static let defaultTimeout: TimeInterval = 60

    /// 在 `queue` 标识的串行域上执行 `body`，并把结果安全地传回 async 调用方。
    ///
    /// - Parameters:
    ///   - queue: 串行域身份；同一 queue 上的 body 严格串行。
    ///   - timeout: 排队 + 执行的总超时；`<= 0` 表示不设超时（不推荐）。
    ///   - body: 需要串行执行的同步工作（如 libgit2 调用）。
    /// - Throws: `body` 抛出的错误、``GitAsyncBridgeError/timeout`` 或
    ///   `CancellationError`（任务被取消时）。
    static func perform<T: Sendable>(
        on queue: DispatchQueue,
        timeout: TimeInterval = defaultTimeout,
        body: @escaping @Sendable () throws -> T
    ) async throws -> T {
        let gate = GitSerialGate.gate(for: queue)
        let workTask = Task.detached(priority: .userInitiated) { () throws -> T in
            try await gate.acquire()
            defer { gate.release() }
            try Task.checkCancellation()
            return try await runBodyOffCooperativePool(body)
        }
        return try await raceCompletion(of: workTask, timeout: timeout)
    }

    // MARK: - 私有方法

    /// 在 GCD 线程上执行同步 `body`，避免长时间 libgit2 调用阻塞协作线程池。
    private static func runBodyOffCooperativePool<T: Sendable>(
        _ body: @escaping @Sendable () throws -> T
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            let guardBox = ContinuationGuard(continuation)
            DispatchQueue.global(qos: .userInitiated).async {
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

    /// 竞速 `workTask` 完成 / 超时 / 任务取消，先到者决定返回结果。
    ///
    /// 被放弃的 `workTask` 会被取消：尚未获得串行权时直接跳过执行；
    /// 已在执行时继续到自然结束（保证串行权正确释放）。
    private static func raceCompletion<T: Sendable>(
        of workTask: Task<T, Error>,
        timeout: TimeInterval
    ) async throws -> T {
        let guardBox = ContinuationGuard<T>()

        let timeoutTask: Task<Void, Never>? = timeout > 0
            ? Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                workTask.cancel()
                guardBox.complete(with: .failure(GitAsyncBridgeError.timeout(seconds: timeout)))
            }
            : nil

        let watchTask = Task { () -> Void in
            let result: Result<T, Error>
            do {
                result = .success(try await workTask.value)
            } catch {
                result = .failure(error)
            }
            guardBox.complete(with: result)
            timeoutTask?.cancel()
        }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guardBox.install(continuation)
            }
        } onCancel: {
            workTask.cancel()
            guardBox.complete(with: .failure(CancellationError()))
            timeoutTask?.cancel()
            watchTask.cancel()
        }
    }
}

/// Git 桥接层错误。
enum GitAsyncBridgeError: LocalizedError {
    /// 排队 + 执行超过 `seconds` 秒仍未完成。
    case timeout(seconds: TimeInterval)

    public var errorDescription: String? {
        switch self {
        case .timeout(let seconds):
            return "Git 操作超时（\(Int(seconds)) 秒）。仓库可能正被其它长时间 Git 操作占用，请稍后重试。"
        }
    }
}

// MARK: - 串行闸门

/// 以 `DispatchQueue` 身份为键的异步串行闸门。
///
/// 同一 queue 对应同一闸门：`acquire()` 按 FIFO 获得执行权，`release()` 交给下一位。
/// `acquire()` 响应任务取消——仍在排队的等待者会被摘除并抛出 `CancellationError`，
/// 其 body 不会再执行。
final class GitSerialGate: @unchecked Sendable {
    private static let registryLock = NSLock()
    /// 强持有 queue，避免其释放后 `ObjectIdentifier` 被复用导致闸门错配。
    /// 访问受 `registryLock` 保护；Swift 6 下静态可变状态需显式标注。
    nonisolated(unsafe) private static var registry: [ObjectIdentifier: (queue: DispatchQueue, gate: GitSerialGate)] = [:]

    /// 取得（或创建）`queue` 对应的闸门。
    static func gate(for queue: DispatchQueue) -> GitSerialGate {
        let key = ObjectIdentifier(queue)
        registryLock.lock()
        defer { registryLock.unlock() }
        if let entry = registry[key] {
            return entry.gate
        }
        let gate = GitSerialGate()
        registry[key] = (queue, gate)
        return gate
    }

    private let lock = NSLock()
    private var isBusy = false
    private var waiters: [GitSerialWaiter] = []

    /// 等待获得执行权。任务被取消时抛 `CancellationError` 且不会持有闸门。
    func acquire() async throws {
        let waiter = GitSerialWaiter()
        enqueueOrGrant(waiter)
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                waiter.install(continuation)
            }
        } onCancel: {
            waiter.cancel()
        }
    }

    /// 入队或立即授权（同步辅助：Swift 6 禁止在 async 上下文直接操作 NSLock）。
    private func enqueueOrGrant(_ waiter: GitSerialWaiter) {
        lock.lock()
        if isBusy {
            waiters.append(waiter)
            lock.unlock()
        } else {
            isBusy = true
            lock.unlock()
            _ = waiter.tryGrant()
        }
    }

    /// 释放执行权，交给下一位有效等待者。
    func release() {
        lock.lock()
        while let next = waiters.first {
            waiters.removeFirst()
            if next.tryGrant() {
                lock.unlock()
                return
            }
            // 已被取消的等待者：跳过并继续找下一位。
        }
        isBusy = false
        lock.unlock()
    }
}

/// `GitSerialGate` 的排队节点：自行处理「授权 / 取消 / continuation 安装」三方竞态。
private final class GitSerialWaiter: @unchecked Sendable {
    private enum State {
        case pending
        case granted
        case abandoned
    }

    private let lock = NSLock()
    private var state: State = .pending
    private var continuation: CheckedContinuation<Void, Error>?
    private var earlyResult: Result<Void, Error>?

    /// 安装 continuation；若结果已先到则立即 resume。
    func install(_ continuation: CheckedContinuation<Void, Error>) {
        lock.lock()
        if let earlyResult {
            self.earlyResult = nil
            lock.unlock()
            continuation.resume(with: earlyResult)
            return
        }
        self.continuation = continuation
        lock.unlock()
    }

    /// 闸门轮到本节点。`false` 表示节点已被取消，闸门应跳过它。
    func tryGrant() -> Bool {
        lock.lock()
        switch state {
        case .abandoned:
            lock.unlock()
            return false
        case .granted:
            lock.unlock()
            return true
        case .pending:
            state = .granted
            if let continuation {
                self.continuation = nil
                lock.unlock()
                continuation.resume()
            } else {
                earlyResult = .success(())
                lock.unlock()
            }
            return true
        }
    }

    /// 任务取消。未获授权则立即以 `CancellationError` 返回；已获授权则不干预
    /// （调用方在 `acquire()` 返回后检查取消状态并释放闸门）。
    func cancel() {
        lock.lock()
        switch state {
        case .pending:
            state = .abandoned
            if let continuation {
                self.continuation = nil
                lock.unlock()
                continuation.resume(throwing: CancellationError())
            } else {
                earlyResult = .failure(CancellationError())
                lock.unlock()
            }
        case .granted, .abandoned:
            lock.unlock()
        }
    }
}

// MARK: - 一次性 continuation 保护

/// 防御性包装：保证一个 continuation 至多被 resume 一次。
///
/// 即使 `perform` 的调用方因 bug 把同一个闭包触发两次，或 body 与某条异常路径
/// 同时尝试完成，这里也能吞掉后续的重复 resume，避免
/// `SWIFT TASK CONTINUATION MISUSE`（resume twice）陷阱。
final class ContinuationGuard<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, Error>?
    private var pending: Result<T, Error>?
    private var isCompleted = false

    init() {}

    init(_ continuation: CheckedContinuation<T, Error>) {
        self.continuation = continuation
    }

    /// 延迟安装 continuation；若结果已先到则立即 resume。
    func install(_ continuation: CheckedContinuation<T, Error>) {
        lock.lock()
        if isCompleted, let pending {
            lock.unlock()
            continuation.resume(with: pending)
            return
        }
        self.continuation = continuation
        lock.unlock()
    }

    func complete(with result: Result<T, Error>) {
        lock.lock()
        guard !isCompleted else {
            lock.unlock()
            return
        }
        isCompleted = true
        pending = result
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(with: result)
    }
}
