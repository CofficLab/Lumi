import Foundation

/// 取消标记：供「协作线程池之外」执行的阻塞代码查询取消状态。
///
/// 池外代码运行在 GCD 线程上，而 `Task.isCancelled` 在那里恒为 `false`
/// （GCD 闭包不继承 Swift Concurrency 的任务上下文），因此取消状态必须
/// 显式传递，不能依赖 `Task.isCancelled`。
public final class RAGCancellationFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    public init() {}

    /// 是否已被取消。
    public var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    /// 标记为已取消。
    public func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }
}

/// 在协作线程池之外执行子进程与阻塞代码。
///
/// ## 为什么不能直接同步调用
///
/// `Process.run()` 之后的 `readDataToEndOfFile()` 与 `waitUntilExit()` 都是
/// **阻塞**调用。工具体跑在 Swift Concurrency 的协作线程池上（见
/// `ToolExecutionRuntime` 的 `Task.detached`），一次大项目 grep 可能阻塞数百
/// 毫秒到数秒；而协作线程池同时负责调度 `MainActor`，被占满时 UI 停止响应。
/// 同类缺陷见 issue #1288（`project_overview` 用无超时的
/// `DispatchSemaphore.wait()` 阻塞协作线程，饿死调度 MainActor 的线程池）。
///
/// 因此本 runner 把**整段阻塞逻辑**放到 GCD 全局队列上执行，再通过
/// continuation 把结果交回 async 调用方：协作线程在此期间完全释放，
/// 随时可以被 MainActor 调度使用。
///
/// ## 语义保持
///
/// 与改造前一致：
/// - stdout / stderr 全部读取（不做尾部截断），避免 ripgrep 的 JSON 行被
///   截断后无法解析；
/// - 保留退出码（ripgrep 的 `1` = 无匹配，`>1` = 真错误）；
/// - 管道 fd 在使用后显式关闭（不依赖 autorelease pool 排空，见
///   `KitShell.ProcessPipeCleanup` 对 EMFILE 的说明）。
///
/// ## 取消
///
/// 任务被取消时终止子进程：ripgrep 收到 SIGTERM 后退出，管道随之关闭，
/// `readDataToEndOfFile()` 返回已有部分数据。调用方随后仍需自行检查取消
/// 状态（`Task.checkCancellation()`）。
public enum RAGProcessRunner {
    /// 子进程执行结果。
    public struct Result: Sendable {
        /// 标准输出原始字节。
        public let standardOutput: Data
        /// 标准错误原始字节（`discardStandardError` 时为空）。
        public let standardError: Data
        /// 退出码。
        public let terminationStatus: Int32

        public init(standardOutput: Data, standardError: Data, terminationStatus: Int32) {
            self.standardOutput = standardOutput
            self.standardError = standardError
            self.terminationStatus = terminationStatus
        }
    }

    /// 进程启动失败。
    public enum LaunchError: LocalizedError, Sendable {
        case failed(String)

        public var errorDescription: String? {
            switch self {
            case .failed(let detail):
                return detail
            }
        }
    }

    /// 在 GCD 全局队列上执行子进程，协作线程在此期间完全释放。
    ///
    /// - Parameters:
    ///   - executable: 可执行文件路径。
    ///   - arguments: 命令行参数。
    ///   - discardStandardError: 为 true 时丢弃 stderr（对应 `FileHandle.nullDevice`）。
    /// - Returns: 子进程的输出与退出码。
    public static func run(
        executable: URL,
        arguments: [String],
        discardStandardError: Bool = false
    ) async throws -> Result {
        let handle = ProcessHandle()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        let result = try executeSynchronously(
                            executable: executable,
                            arguments: arguments,
                            discardStandardError: discardStandardError,
                            handle: handle
                        )
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        } onCancel: {
            handle.requestTermination()
        }
    }

    /// 在 GCD 全局队列上执行任意阻塞闭包。
    ///
    /// 闭包内通过传入的 `RAGCancellationFlag` 查询取消状态——池外代码里
    /// `Task.isCancelled` 恒为 false，不能用于取消判定。
    public static func runOffPool<T: Sendable>(
        _ body: @escaping @Sendable (RAGCancellationFlag) throws -> T
    ) async throws -> T {
        let flag = RAGCancellationFlag()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        let value = try body(flag)
                        if flag.isCancelled {
                            throw CancellationError()
                        }
                        continuation.resume(returning: value)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        } onCancel: {
            flag.cancel()
        }
    }

    // MARK: - 私有实现

    /// 同步执行子进程。
    ///
    /// **必须在协作线程池之外调用**（见 `run`）。
    private static func executeSynchronously(
        executable: URL,
        arguments: [String],
        discardStandardError: Bool,
        handle: ProcessHandle
    ) throws -> Result {
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = discardStandardError ? FileHandle.nullDevice : errorPipe

        // 确定性回收管道 fd，避免热路径上依赖 autorelease pool 造成 fd 泄漏。
        defer {
            try? outputPipe.fileHandleForReading.close()
            try? outputPipe.fileHandleForWriting.close()
            try? errorPipe.fileHandleForReading.close()
            try? errorPipe.fileHandleForWriting.close()
        }

        handle.install(process)
        do {
            try process.run()
        } catch {
            handle.clear()
            throw LaunchError.failed(error.localizedDescription)
        }
        handle.markLaunched()

        // stdout 与 stderr **必须并行读取**：顺序读取时，若子进程往 stderr
        // 写入超过管道缓冲区（64KB）大小的内容（例如扫描大目录时大量
        // "Permission denied" 警告），它会阻塞在 write 上，而我们在读 stdout，
        // 双方互等形成死锁。
        let stderrReader = DispatchQueue(
            label: "com.coffic.lumi.rag.process.stderr",
            qos: .utility
        )
        let errorBox = DataBox()
        if !discardStandardError {
            stderrReader.async {
                errorBox.set(errorPipe.fileHandleForReading.readDataToEndOfFile())
            }
        }

        let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
        // 等待 stderr 读完，确保上面的 `defer` 关闭 fd 时没有读操作仍在进行。
        stderrReader.sync {}
        let errorOutput = errorBox.get()

        process.waitUntilExit()
        let status = process.terminationStatus
        handle.clear()

        return Result(
            standardOutput: output,
            standardError: errorOutput,
            terminationStatus: status
        )
    }

    /// 子进程句柄：支持在任务取消时终止进程。
    private final class ProcessHandle: @unchecked Sendable {
        private let lock = NSLock()
        private var process: Process?
        private var launched = false
        private var terminationRequested = false

        /// 登记待终止的进程（尚未启动）。
        func install(_ process: Process) {
            lock.lock()
            self.process = process
            lock.unlock()
        }

        /// 标记进程已启动；若此前已请求终止，此刻补上终止动作。
        func markLaunched() {
            lock.lock()
            launched = true
            let shouldTerminate = terminationRequested
            let target = process
            lock.unlock()
            if shouldTerminate {
                target?.terminate()
            }
        }

        /// 清除登记（进程已结束）。
        func clear() {
            lock.lock()
            process = nil
            launched = false
            lock.unlock()
        }

        /// 请求终止进程。
        ///
        /// 未启动的进程只记录请求，由 `markLaunched()` 在启动后补做；
        /// 已结束的进程无需处理。
        func requestTermination() {
            lock.lock()
            terminationRequested = true
            let isLaunched = launched
            let target = process
            lock.unlock()
            guard isLaunched, let target, target.isRunning else { return }
            target.terminate()
        }
    }

    /// 跨线程传递读取到的字节。
    private final class DataBox: @unchecked Sendable {
        private let lock = NSLock()
        private var data = Data()

        func set(_ newValue: Data) {
            lock.lock()
            data = newValue
            lock.unlock()
        }

        func get() -> Data {
            lock.lock()
            defer { lock.unlock() }
            return data
        }
    }
}
