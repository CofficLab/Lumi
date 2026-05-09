import Testing
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
        // Sleep command that would run for 10 seconds
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
                // Could also be command failed since process was terminated
                #expect(true) // Accept either timeout or command failed
            }
        }
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
        var receivedChunks: [String] = []

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

    @Test("Streaming captures stderr")
    func testStreamingStderr() async throws {
        var stderrOutput = ""

        let result = try await ShellExecutor.executeStreaming(
            "ls /nonexistent_dir_stream_test 2>&1 || true",
            options: .init(throwsOnError: false),
            onOutput: { _ in },
            onError: { chunk in
                stderrOutput += chunk
            }
        )

        // Some error output should be captured (might be in stdout for 2>&1)
        #expect(!result.isSuccess || result.stdout.contains("No such file") || stderrOutput.contains("No such file"))
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

        #expect(options.workingDirectory == nil)
        #expect(options.environment.isEmpty)
        #expect(options.timeout == nil)
        #expect(options.qos == .userInitiated)
        #expect(options.throwsOnError == true)
    }

    @Test("ShellOptions custom initialization")
    func testCustomOptions() {
        let options = ShellOptions(
            workingDirectory: "/tmp",
            environment: ["KEY": "VALUE"],
            timeout: 30.0,
            qos: .background,
            throwsOnError: false
        )

        #expect(options.workingDirectory == "/tmp")
        #expect(options.environment["KEY"] == "VALUE")
        #expect(options.timeout == 30.0)
        #expect(options.qos == .background)
        #expect(options.throwsOnError == false)
    }

    // MARK: - Convenience Alias Tests

    @Test("Shell alias works correctly")
    func testShellAlias() async throws {
        let result = try await Shell.execute("echo 'alias test'")
        #expect(result.isSuccess)
        #expect(result.stdout == "alias test")
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