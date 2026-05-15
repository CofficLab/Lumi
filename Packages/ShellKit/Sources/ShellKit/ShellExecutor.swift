import Darwin
import Foundation

/// Thread-safe buffer for collecting output data
private final class ThreadSafeBuffer: @unchecked Sendable {
    private var data = Data()
    private let lock = NSLock()

    func append(_ newData: Data) {
        lock.lock()
        data.append(newData)
        lock.unlock()
    }

    func getData() -> Data {
        lock.lock()
        let result = data
        lock.unlock()
        return result
    }

    func getString() -> String {
        String(data: getData(), encoding: .utf8) ?? ""
    }
}

/// Thread-safe string buffer for streaming output
private final class ThreadSafeStringBuffer: @unchecked Sendable {
    private var text = ""
    private let lock = NSLock()

    func append(_ newText: String) {
        lock.lock()
        text += newText
        lock.unlock()
    }

    func getString() -> String {
        lock.lock()
        let result = text
        lock.unlock()
        return result
    }
}

/// Modern async shell command executor
///
/// Provides safe, non-blocking Process execution with:
/// - Async/await support using withCheckedThrowingContinuation
/// - Streaming output callbacks
/// - Timeout and cancellation support
/// - Background queue execution (never blocks MainActor)
///
/// ## Basic Usage
/// ```swift
/// let result = try await ShellExecutor.execute("git status")
/// print(result.stdout)
/// ```
///
/// ## With Options
/// ```swift
/// let result = try await ShellExecutor.execute(
///     "npm install",
///     options: .init(workingDirectory: "/path/to/project", timeout: 60)
/// )
/// ```
///
/// ## Streaming Output
/// ```swift
/// try await ShellExecutor.executeStreaming(
///     "docker build -t myapp .",
///     onOutput: { print($0) },
///     onError: { print("Error: \($0)") }
/// )
/// ```
public enum ShellExecutor {
    // MARK: - Simple Execution

    /// Execute a shell command and return the result
    ///
    /// - Parameters:
    ///   - command: The command to execute (supports shell syntax like pipes)
    ///   - options: Execution options
    /// - Returns: ShellResult with stdout, stderr, and exit code
    /// - Throws: ShellError on failure or timeout
    public static func execute(
        _ command: String,
        options: ShellOptions = .defaultOptions
    ) async throws -> ShellResult {
        try await execute(
            executable: options.shellExecutable,
            arguments: ["-c", command],
            options: options
        )
    }

    /// Execute an executable with explicit arguments
    ///
    /// - Parameters:
    ///   - executable: Path to the executable
    ///   - arguments: Arguments to pass to the executable
    ///   - options: Execution options
    /// - Returns: ShellResult with stdout, stderr, and exit code
    /// - Throws: ShellError on failure or timeout
    public static func execute(
        executable: String,
        arguments: [String] = [],
        options: ShellOptions = .defaultOptions
    ) async throws -> ShellResult {
        let startedAt = Date()
        let stdoutBuffer = ThreadSafeBuffer()
        let stderrBuffer = ThreadSafeBuffer()

        let result = try await runProcess(
            executable: executable,
            arguments: arguments,
            options: options,
            stdoutHandler: { stdoutBuffer.append($0) },
            stderrHandler: { stderrBuffer.append($0) }
        )
        let command = commandDescription(executable: executable, arguments: arguments)
        if result.timedOut {
            throw ShellError.timeout(command: command, seconds: options.timeout ?? 0)
        }
        if result.wasCancelled {
            throw ShellError.cancelled(command: command)
        }

        let duration = Date().timeIntervalSince(startedAt)
        let stdout = stdoutBuffer.getString()
        let stderr = stderrBuffer.getString()

        let shellResult = ShellResult(
            exitCode: result.exitCode,
            stdout: stdout.trimmingCharacters(in: .whitespacesAndNewlines),
            stderr: stderr.trimmingCharacters(in: .whitespacesAndNewlines),
            duration: duration
        )

        if options.throwsOnError && result.exitCode != 0 {
            throw ShellError.commandFailed(
                exitCode: result.exitCode,
                stdout: shellResult.stdout,
                stderr: shellResult.stderr
            )
        }

        return shellResult
    }

    // MARK: - Streaming Execution

    /// Execute a command with streaming output callbacks
    ///
    /// - Parameters:
    ///   - command: The command to execute
    ///   - options: Execution options
    ///   - onOutput: Callback for stdout chunks (called on background thread)
    ///   - onError: Callback for stderr chunks (called on background thread)
    /// - Returns: ShellResult with final exit code and captured output
    /// - Throws: ShellError on failure or timeout
    public static func executeStreaming(
        _ command: String,
        options: ShellOptions = .defaultOptions,
        onOutput: @escaping @Sendable (String) -> Void,
        onError: @escaping @Sendable (String) -> Void = { _ in },
        onOutputData: @escaping @Sendable (Data) -> Void = { _ in },
        onErrorData: @escaping @Sendable (Data) -> Void = { _ in }
    ) async throws -> ShellResult {
        try await executeStreaming(
            executable: options.shellExecutable,
            arguments: ["-c", command],
            options: options,
            onOutput: onOutput,
            onError: onError,
            onOutputData: onOutputData,
            onErrorData: onErrorData
        )
    }

    /// Execute an executable with streaming output callbacks
    public static func executeStreaming(
        executable: String,
        arguments: [String] = [],
        options: ShellOptions = .defaultOptions,
        onOutput: @escaping @Sendable (String) -> Void,
        onError: @escaping @Sendable (String) -> Void = { _ in },
        onOutputData: @escaping @Sendable (Data) -> Void = { _ in },
        onErrorData: @escaping @Sendable (Data) -> Void = { _ in }
    ) async throws -> ShellResult {
        let startedAt = Date()
        let stdoutBuffer = ThreadSafeStringBuffer()
        let stderrBuffer = ThreadSafeStringBuffer()

        let result = try await runProcess(
            executable: executable,
            arguments: arguments,
            options: options,
            stdoutHandler: { data in
                onOutputData(data)
                if let text = String(data: data, encoding: .utf8) {
                    stdoutBuffer.append(text)
                    onOutput(text)
                }
            },
            stderrHandler: { data in
                onErrorData(data)
                if let text = String(data: data, encoding: .utf8) {
                    stderrBuffer.append(text)
                    onError(text)
                }
            }
        )
        let command = commandDescription(executable: executable, arguments: arguments)
        if result.timedOut {
            throw ShellError.timeout(command: command, seconds: options.timeout ?? 0)
        }
        if result.wasCancelled {
            throw ShellError.cancelled(command: command)
        }

        let duration = Date().timeIntervalSince(startedAt)

        let shellResult = ShellResult(
            exitCode: result.exitCode,
            stdout: stdoutBuffer.getString().trimmingCharacters(in: .whitespacesAndNewlines),
            stderr: stderrBuffer.getString().trimmingCharacters(in: .whitespacesAndNewlines),
            duration: duration
        )

        if options.throwsOnError && result.exitCode != 0 {
            throw ShellError.commandFailed(
                exitCode: result.exitCode,
                stdout: shellResult.stdout,
                stderr: shellResult.stderr
            )
        }

        return shellResult
    }

    // MARK: - Check Command

    /// Check if a command is available in the system
    ///
    /// - Parameter command: The command name to check (e.g., "git", "docker")
    /// - Returns: The full path to the command if available, nil otherwise
    public static func findCommand(_ command: String) async -> String? {
        do {
            let result = try await execute(
                executable: "/usr/bin/which",
                arguments: [command],
                options: .init(throwsOnError: false)
            )
            return result.isSuccess ? result.stdout : nil
        } catch {
            return nil
        }
    }

    /// Check if a command is available (synchronous version)
    public static func findCommandSync(_ command: String) -> String? {
        let semaphore = DispatchSemaphore(value: 0)
        let box = SyncResultBox()

        Task {
            let result = await findCommand(command)
            box.set(result)
            semaphore.signal()
        }
        semaphore.wait()
        return box.get()
    }

    // MARK: - Core Process Runner

    private struct ProcessResult: Sendable {
        let exitCode: Int32
        let wasCancelled: Bool
        let timedOut: Bool
    }

    private final class SyncResultBox: @unchecked Sendable {
        private let lock = NSLock()
        private var value: String?

        func set(_ value: String?) {
            lock.lock()
            self.value = value
            lock.unlock()
        }

        func get() -> String? {
            lock.lock()
            let result = value
            lock.unlock()
            return result
        }
    }

    private final class ProcessExecutionState: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<ProcessResult, Error>?
        private var process: Process?
        private var timeoutItem: DispatchWorkItem?
        private var wasCancelled = false
        private var timedOut = false

        init(continuation: CheckedContinuation<ProcessResult, Error>) {
            self.continuation = continuation
        }

        func setProcess(_ process: Process) {
            lock.lock()
            self.process = process
            lock.unlock()
        }

        func setTimeoutItem(_ item: DispatchWorkItem?) {
            lock.lock()
            timeoutItem = item
            lock.unlock()
        }

        func timeout(options: ShellOptions) {
            let process: Process?
            lock.lock()
            timedOut = true
            wasCancelled = true
            process = self.process
            lock.unlock()

            if let process {
                terminate(process: process, options: options)
            }
        }

        func cancel(options: ShellOptions) {
            let process: Process?
            lock.lock()
            wasCancelled = true
            process = self.process
            lock.unlock()

            if let process {
                terminate(process: process, options: options)
            }
        }

        func complete(exitCode: Int32) {
            let continuation: CheckedContinuation<ProcessResult, Error>?
            let result: ProcessResult
            lock.lock()
            timeoutItem?.cancel()
            continuation = self.continuation
            self.continuation = nil
            result = ProcessResult(exitCode: exitCode, wasCancelled: wasCancelled, timedOut: timedOut)
            lock.unlock()

            continuation?.resume(returning: result)
        }

        func fail(_ error: Error) {
            let continuation: CheckedContinuation<ProcessResult, Error>?
            lock.lock()
            timeoutItem?.cancel()
            continuation = self.continuation
            self.continuation = nil
            lock.unlock()

            continuation?.resume(throwing: error)
        }
    }

    private final class ProcessExecutionStateStore: @unchecked Sendable {
        private let lock = NSLock()
        private var state: ProcessExecutionState?

        func set(_ state: ProcessExecutionState) {
            lock.lock()
            self.state = state
            lock.unlock()
        }

        func cancel(options: ShellOptions) {
            lock.lock()
            let state = self.state
            lock.unlock()
            state?.cancel(options: options)
        }
    }

    private static func runProcess(
        executable: String,
        arguments: [String],
        options: ShellOptions,
        stdoutHandler: @escaping @Sendable (Data) -> Void,
        stderrHandler: @escaping @Sendable (Data) -> Void
    ) async throws -> ProcessResult {
        let stateStore = ProcessExecutionStateStore()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let state = ProcessExecutionState(continuation: continuation)
                stateStore.set(state)
                DispatchQueue.global(qos: options.qos).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = arguments
                state.setProcess(process)

                // Set working directory
                if let dir = options.workingDirectory {
                    process.currentDirectoryURL = URL(fileURLWithPath: dir)
                }

                // Set environment
                var env = ProcessInfo.processInfo.environment
                for (key, value) in options.environment {
                    env[key] = value
                }
                process.environment = env

                // Set up pipes
                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                // Set up termination handler
                process.terminationHandler = { [stdoutPipe, stderrPipe] _ in
                    // Read final data
                    let finalStdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    let finalStderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                    if !finalStdout.isEmpty {
                        stdoutHandler(finalStdout)
                    }
                    if !finalStderr.isEmpty {
                        stderrHandler(finalStderr)
                    }

                    // Clean up handlers
                    stdoutPipe.fileHandleForReading.readabilityHandler = nil
                    stderrPipe.fileHandleForReading.readabilityHandler = nil

                    state.complete(exitCode: process.terminationStatus)
                }

                // Set up streaming handlers
                stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if !data.isEmpty {
                        stdoutHandler(data)
                    }
                }

                stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if !data.isEmpty {
                        stderrHandler(data)
                    }
                }

                // Set up timeout if specified
                if let timeout = options.timeout {
                    let timeoutItem = DispatchWorkItem {
                        state.timeout(options: options)
                    }
                    state.setTimeoutItem(timeoutItem)
                    DispatchQueue.global(qos: options.qos)
                        .asyncAfter(deadline: .now() + timeout, execute: timeoutItem)
                }

                // Launch process
                do {
                    try process.run()
                } catch {
                    stdoutPipe.fileHandleForReading.readabilityHandler = nil
                    stderrPipe.fileHandleForReading.readabilityHandler = nil
                    state.fail(ShellError.launchFailed(
                        command: executable,
                        reason: error.localizedDescription
                    ))
                }
            }
            }
        } onCancel: {
            stateStore.cancel(options: options)
        }
    }

    private static func commandDescription(executable: String, arguments: [String]) -> String {
        ([executable] + arguments).joined(separator: " ")
    }

    private static func terminate(process: Process, options: ShellOptions) {
        let pid = process.processIdentifier
        if options.terminatesProcessTree, pid > 0 {
            terminateChildren(of: pid, signal: SIGTERM)
        }
        if process.isRunning {
            process.terminate()
        }

        let gracePeriod = max(0, options.terminationGracePeriod)
        DispatchQueue.global(qos: options.qos).asyncAfter(deadline: .now() + gracePeriod) {
            if options.terminatesProcessTree, pid > 0 {
                terminateChildren(of: pid, signal: SIGKILL)
            }
            if process.isRunning, pid > 0 {
                kill(pid, SIGKILL)
            }
        }
    }

    private static func terminateChildren(of pid: Int32, signal: Int32) {
        let pkill = Process()
        pkill.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        pkill.arguments = ["-\(signal)", "-P", "\(pid)"]
        pkill.standardOutput = Pipe()
        pkill.standardError = Pipe()
        try? pkill.run()
    }
}
