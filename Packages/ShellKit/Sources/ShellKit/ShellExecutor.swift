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
            executable: "/bin/bash",
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
        onError: @escaping @Sendable (String) -> Void = { _ in }
    ) async throws -> ShellResult {
        try await executeStreaming(
            executable: "/bin/bash",
            arguments: ["-c", command],
            options: options,
            onOutput: onOutput,
            onError: onError
        )
    }

    /// Execute an executable with streaming output callbacks
    public static func executeStreaming(
        executable: String,
        arguments: [String] = [],
        options: ShellOptions = .defaultOptions,
        onOutput: @escaping @Sendable (String) -> Void,
        onError: @escaping @Sendable (String) -> Void = { _ in }
    ) async throws -> ShellResult {
        let startedAt = Date()
        let stdoutBuffer = ThreadSafeStringBuffer()
        let stderrBuffer = ThreadSafeStringBuffer()

        let result = try await runProcess(
            executable: executable,
            arguments: arguments,
            options: options,
            stdoutHandler: { data in
                if let text = String(data: data, encoding: .utf8) {
                    stdoutBuffer.append(text)
                    onOutput(text)
                }
            },
            stderrHandler: { data in
                if let text = String(data: data, encoding: .utf8) {
                    stderrBuffer.append(text)
                    onError(text)
                }
            }
        )

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
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [command]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                return String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {}

        return nil
    }

    // MARK: - Core Process Runner

    private struct ProcessResult: Sendable {
        let exitCode: Int32
        let wasCancelled: Bool
    }

    private static func runProcess(
        executable: String,
        arguments: [String],
        options: ShellOptions,
        stdoutHandler: @escaping @Sendable (Data) -> Void,
        stderrHandler: @escaping @Sendable (Data) -> Void
    ) async throws -> ProcessResult {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: options.qos).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = arguments

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

                // Track cancellation
                var wasCancelled = false
                var timeoutItem: DispatchWorkItem?

                // Set up termination handler
                process.terminationHandler = { [stdoutPipe, stderrPipe] _ in
                    // Clean up timeout if set
                    timeoutItem?.cancel()

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

                    continuation.resume(returning: ProcessResult(
                        exitCode: process.terminationStatus,
                        wasCancelled: wasCancelled
                    ))
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
                    timeoutItem = DispatchWorkItem {
                        if process.isRunning {
                            wasCancelled = true
                            process.terminate()
                        }
                    }
                    DispatchQueue.global(qos: options.qos)
                        .asyncAfter(deadline: .now() + timeout, execute: timeoutItem!)
                }

                // Launch process
                do {
                    try process.run()
                } catch {
                    timeoutItem?.cancel()
                    stdoutPipe.fileHandleForReading.readabilityHandler = nil
                    stderrPipe.fileHandleForReading.readabilityHandler = nil
                    continuation.resume(throwing: ShellError.launchFailed(
                        command: executable,
                        reason: error.localizedDescription
                    ))
                }
            }
        }
    }
}