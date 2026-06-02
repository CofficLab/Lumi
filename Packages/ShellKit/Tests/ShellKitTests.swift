import Testing
import Darwin
import Foundation
@testable import ShellKit

@Suite("ShellExecutor Tests")
struct ShellExecutorTests {

    // MARK: - Basic Execution Tests

    @Test("Execute simple command returns correct output")
    func testSimpleCommand() async throws {
        let result = try await ShellExecutor.execute("echo 'Hello World'")

        #expect(result.isSuccess)
        #expect(result.stdout == "Hello World")
        #expect(result.stderr.isEmpty)
        #expect(result.duration != nil)
        #expect(result.duration! > 0)
    }

    @Test("Execute command with pipe")
    func testPipedCommand() async throws {
        let result = try await ShellExecutor.execute("echo 'test' | cat")

        #expect(result.isSuccess)
        #expect(result.stdout == "test")
    }

    @Test("Execute command with multiple pipes")
    func testMultiplePipes() async throws {
        let result = try await ShellExecutor.execute("echo 'hello world' | tr ' ' '-' | cat")

        #expect(result.isSuccess)
        #expect(result.stdout == "hello-world")
    }

    @Test("Execute command with explicit executable")
    func testExplicitExecutable() async throws {
        let result = try await ShellExecutor.execute(
            executable: "/bin/echo",
            arguments: ["explicit test"]
        )

        #expect(result.isSuccess)
        #expect(result.stdout == "explicit test")
    }

    @Test("Command-string execution can use zsh")
    func testShellExecutableOptionUsesZsh() async throws {
        let result = try await ShellExecutor.execute(
            "echo ${ZSH_VERSION:+zsh}",
            options: .init(shellExecutable: "/bin/zsh")
        )

        #expect(result.isSuccess)
        #expect(result.stdout == "zsh")
    }

    // MARK: - Working Directory Tests

    @Test("Execute command in specific working directory")
    func testWorkingDirectory() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let result = try await ShellExecutor.execute(
            "pwd",
            options: .init(workingDirectory: tempDir.path)
        )

        #expect(result.isSuccess)
        // Compare resolved paths since macOS /var is symlink to /private/var
        let resultPath = URL(fileURLWithPath: result.stdout).resolvingSymlinksInPath()
        let expectedPath = tempDir.resolvingSymlinksInPath()
        #expect(resultPath == expectedPath)
    }

    @Test("Working directory affects relative paths")
    func testWorkingDirectoryRelativePath() async throws {
        // Create a temp file
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("shellkit_test.txt")
        try "test content".write(to: testFile, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: testFile)
        }

        let result = try await ShellExecutor.execute(
            "cat shellkit_test.txt",
            options: .init(workingDirectory: tempDir.path)
        )

        #expect(result.isSuccess)
        #expect(result.stdout == "test content")
    }

    // MARK: - Environment Tests

    @Test("Custom environment variable is accessible")
    func testCustomEnvironment() async throws {
        let result = try await ShellExecutor.execute(
            "echo $SHELLKIT_TEST_VAR",
            options: .init(environment: ["SHELLKIT_TEST_VAR": "custom_value"])
        )

        #expect(result.isSuccess)
        #expect(result.stdout == "custom_value")
    }

    @Test("Environment preserves system PATH")
    func testEnvironmentPreservesPath() async throws {
        let result = try await ShellExecutor.execute(
            "echo $PATH",
            options: .init(environment: ["CUSTOM_VAR": "test"])
        )

        #expect(result.isSuccess)
        #expect(!result.stdout.isEmpty)
        #expect(result.stdout.contains("/"))
    }

    // MARK: - Error Handling Tests

    @Test("Command failure throws ShellError")
    func testCommandFailureThrows() async throws {
        do {
            _ = try await ShellExecutor.execute("ls /nonexistent_directory_12345")
            Issue.record("Should have thrown error")
        } catch let error as ShellError {
            #expect(error.errorDescription != nil)
            if case .commandFailed(let exitCode, _, _) = error {
                #expect(exitCode != 0)
            } else {
                Issue.record("Wrong error type")
            }
        }
    }

    @Test("Command failure with throwsOnError=false returns result")
    func testCommandFailureNoThrow() async throws {
        let result = try await ShellExecutor.execute(
            "ls /nonexistent_directory_12345",
            options: .init(throwsOnError: false)
        )

        #expect(!result.isSuccess)
        #expect(result.exitCode != 0)
        #expect(!result.stderr.isEmpty)
    }

    @Test("Invalid executable throws launchFailed")
    func testInvalidExecutable() async throws {
        do {
            _ = try await ShellExecutor.execute(
                executable: "/nonexistent/executable",
                arguments: []
            )
            Issue.record("Should have thrown error")
        } catch let error as ShellError {
            if case .launchFailed(_, _) = error {
                // Expected
            } else {
                Issue.record("Wrong error type: \(error)")
            }
        }
    }

    // MARK: - Timeout Tests

    @Test("Timeout terminates long-running command")
    func testTimeout() async throws {
        do {
            _ = try await ShellExecutor.execute(
                "sleep 10",
                options: .init(timeout: 0.5)
            )
            Issue.record("Should have thrown timeout error")
        } catch let error as ShellError {
            if case .timeout(_, let seconds) = error {
                #expect(seconds == 0.5)
            } else {
                Issue.record("Wrong error type: \(error)")
            }
        }
    }

    @Test("Timeout still throws when throwsOnError is false")
    func testTimeoutIgnoresThrowsOnErrorFalse() async throws {
        do {
            _ = try await ShellExecutor.execute(
                "sleep 10",
                options: .init(timeout: 0.5, throwsOnError: false)
            )
            Issue.record("Should have thrown timeout error")
        } catch let error as ShellError {
            if case .timeout = error {
                // Expected
            } else {
                Issue.record("Wrong error type: \(error)")
            }
        }
    }

    @Test("Timeout terminates child processes")
    func testTimeoutTerminatesChildProcess() async throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let pidFile = tempDir.appendingPathComponent("child.pid")
        let command = "sleep 20 & echo $! > '\(pidFile.path)'; wait"

        do {
            _ = try await ShellExecutor.execute(
                command,
                options: .init(shellExecutable: "/bin/zsh", timeout: 0.5)
            )
            Issue.record("Should have thrown timeout error")
        } catch let error as ShellError {
            if case .timeout = error {
                // Expected
            } else {
                Issue.record("Wrong error type: \(error)")
            }
        }

        let pid = try readPID(from: pidFile)
        try await Task.sleep(nanoseconds: 1_000_000_000)
        #expect(!isProcessRunning(pid))
    }

    @Test("Quick command completes before timeout")
    func testQuickCommandBeforeTimeout() async throws {
        let result = try await ShellExecutor.execute(
            "echo 'quick'",
            options: .init(timeout: 5.0)
        )

        #expect(result.isSuccess)
        #expect(result.stdout == "quick")
        #expect(result.duration! < 5.0)
    }

    // MARK: - Streaming Tests

    @Test("Streaming captures output incrementally")
    func testStreamingOutput() async throws {
        let receivedChunks = LockedArray<String>()

        let result = try await ShellExecutor.executeStreaming(
            "echo 'line1'; echo 'line2'; echo 'line3'",
            onOutput: { chunk in
                receivedChunks.append(chunk)
            }
        )

        #expect(result.isSuccess)
        #expect(receivedChunks.count >= 1)
        #expect(result.stdout.contains("line1"))
        #expect(result.stdout.contains("line2"))
        #expect(result.stdout.contains("line3"))
    }

    @Test("Streaming exposes raw output data")
    func testStreamingOutputData() async throws {
        let byteCount = LockedCounter()

        let result = try await ShellExecutor.executeStreaming(
            "printf 'abc'",
            onOutput: { _ in },
            onOutputData: { data in
                byteCount.add(data.count)
            }
        )

        #expect(result.isSuccess)
        #expect(result.stdout == "abc")
        #expect(byteCount.value == 3)
    }

    @Test("Streaming captures stderr")
    func testStreamingStderr() async throws {
        let stderrOutput = LockedString()
        let stderrBytes = LockedCounter()

        let result = try await ShellExecutor.executeStreaming(
            "ls /nonexistent_dir_stream_test",
            options: .init(throwsOnError: false),
            onOutput: { _ in },
            onError: { chunk in
                stderrOutput.append(chunk)
            },
            onErrorData: { data in
                stderrBytes.add(data.count)
            }
        )

        #expect(!result.isSuccess)
        #expect(stderrOutput.value.contains("No such file"))
        #expect(stderrBytes.value > 0)
    }

    @Test("Cancellation terminates child processes")
    func testCancellationTerminatesChildProcess() async throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let pidFile = tempDir.appendingPathComponent("cancelled-child.pid")
        let command = "sleep 20 & echo $! > '\(pidFile.path)'; wait"
        let task = Task {
            try await ShellExecutor.execute(
                command,
                options: .init(shellExecutable: "/bin/zsh")
            )
        }

        try await waitForFile(pidFile)
        let pid = try readPID(from: pidFile)
        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Should have thrown cancellation error")
        } catch let error as ShellError {
            if case .cancelled = error {
                // Expected
            } else {
                Issue.record("Wrong error type: \(error)")
            }
        }

        try await Task.sleep(nanoseconds: 1_000_000_000)
        #expect(!isProcessRunning(pid))
    }

    // MARK: - Command Lookup Tests

    @Test("findCommand returns path for existing command")
    func testFindCommand() async {
        let gitPath = await ShellExecutor.findCommand("git")
        #expect(gitPath != nil)
        #expect(gitPath!.contains("git"))
    }

    @Test("findCommand returns nil for nonexistent command")
    func testFindNonexistentCommand() async {
        let path = await ShellExecutor.findCommand("nonexistent_command_xyz")
        #expect(path == nil)
    }

    @Test("findCommandSync returns correct result")
    func testFindCommandSync() {
        let echoPath = ShellExecutor.findCommandSync("echo")
        #expect(echoPath != nil)
        #expect(echoPath!.contains("/bin/echo") || echoPath!.contains("/usr/bin/echo"))
    }

    // MARK: - Result Type Tests

    @Test("ShellResult isSuccess property works correctly")
    func testResultIsSuccess() {
        let successResult = ShellResult(exitCode: 0, stdout: "ok", stderr: "")
        let failureResult = ShellResult(exitCode: 1, stdout: "", stderr: "error")

        #expect(successResult.isSuccess)
        #expect(!failureResult.isSuccess)
    }

    @Test("ShellResult stores duration")
    func testResultDuration() {
        let result = ShellResult(exitCode: 0, stdout: "test", stderr: "", duration: 1.5)
        #expect(result.duration == 1.5)

        let noDurationResult = ShellResult(exitCode: 0, stdout: "test", stderr: "")
        #expect(noDurationResult.duration == nil)
    }

    // MARK: - Options Tests

    @Test("ShellOptions default values")
    func testDefaultOptions() {
        let options = ShellOptions.defaultOptions

        #expect(options.shellExecutable == "/bin/bash")
        #expect(options.workingDirectory == nil)
        #expect(options.environment.isEmpty)
        #expect(options.timeout == nil)
        #expect(options.qos == .userInitiated)
        #expect(options.throwsOnError == true)
        #expect(options.terminatesProcessTree == true)
        #expect(options.terminationGracePeriod == 2.0)
    }

    @Test("ShellOptions custom initialization")
    func testCustomOptions() {
        let options = ShellOptions(
            shellExecutable: "/bin/zsh",
            workingDirectory: "/tmp",
            environment: ["KEY": "VALUE"],
            timeout: 30.0,
            qos: .background,
            throwsOnError: false,
            terminatesProcessTree: false,
            terminationGracePeriod: 0.25
        )

        #expect(options.shellExecutable == "/bin/zsh")
        #expect(options.workingDirectory == "/tmp")
        #expect(options.environment["KEY"] == "VALUE")
        #expect(options.timeout == 30.0)
        #expect(options.qos == .background)
        #expect(options.throwsOnError == false)
        #expect(options.terminatesProcessTree == false)
        #expect(options.terminationGracePeriod == 0.25)
    }

    // MARK: - Convenience Alias Tests

    @Test("Shell alias works correctly")
    func testShellAlias() async throws {
        let result = try await Shell.execute("echo 'alias test'")
        #expect(result.isSuccess)
        #expect(result.stdout == "alias test")
    }
}

private func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("ShellKitTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func waitForFile(_ url: URL, timeout: TimeInterval = 2.0) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if FileManager.default.fileExists(atPath: url.path) {
            return
        }
        try await Task.sleep(nanoseconds: 50_000_000)
    }
    Issue.record("Timed out waiting for file: \(url.path)")
}

private func readPID(from url: URL) throws -> Int32 {
    let raw = try String(contentsOf: url, encoding: .utf8)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    guard let pid = Int32(raw) else {
        Issue.record("Invalid pid: \(raw)")
        return -1
    }
    return pid
}

private func isProcessRunning(_ pid: Int32) -> Bool {
    guard pid > 0 else { return false }
    return kill(pid, 0) == 0
}

private final class LockedArray<Element>: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Element] = []

    var count: Int {
        lock.lock()
        let result = values.count
        lock.unlock()
        return result
    }

    func append(_ value: Element) {
        lock.lock()
        values.append(value)
        lock.unlock()
    }
}

private final class LockedString: @unchecked Sendable {
    private let lock = NSLock()
    private var text = ""

    var value: String {
        lock.lock()
        let result = text
        lock.unlock()
        return result
    }

    func append(_ value: String) {
        lock.lock()
        text += value
        lock.unlock()
    }
}

private final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.lock()
        let result = count
        lock.unlock()
        return result
    }

    func add(_ value: Int) {
        lock.lock()
        count += value
        lock.unlock()
    }
}

@Suite("ShellError Tests")
struct ShellErrorTests {

    @Test("commandFailed error description")
    func testCommandFailedDescription() {
        let error = ShellError.commandFailed(exitCode: 1, stdout: "", stderr: "some error")
        #expect(error.errorDescription?.contains("exit code 1") == true)
        #expect(error.errorDescription?.contains("some error") == true)
    }

    @Test("timeout error description")
    func testTimeoutDescription() {
        let error = ShellError.timeout(command: "sleep 100", seconds: 5.0)
        #expect(error.errorDescription?.contains("sleep 100") == true)
        #expect(error.errorDescription?.contains("5") == true)
    }

    @Test("launchFailed error description")
    func testLaunchFailedDescription() {
        let error = ShellError.launchFailed(command: "/bad/path", reason: "not found")
        #expect(error.errorDescription?.contains("/bad/path") == true)
        #expect(error.errorDescription?.contains("not found") == true)
    }

    @Test("cancelled error description")
    func testCancelledDescription() {
        let error = ShellError.cancelled(command: "test command")
        #expect(error.errorDescription?.contains("test command") == true)
        #expect(error.errorDescription?.contains("cancelled") == true)
    }

    @Test("decodingError error description")
    func testDecodingErrorDescription() {
        let error = ShellError.decodingError(command: "test")
        #expect(error.errorDescription?.contains("decode") == true)
    }
}
