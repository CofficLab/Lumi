import Foundation
import SuperLogKit

public actor ScriptTaskRunner: SuperLog {
    public nonisolated static let emoji = "▶️"

    private var currentProcess: Process?

    public func runScript(
        _ script: String,
        projectPath: String,
        arguments: [String] = []
    ) async -> JSScriptResult {
        let packageManager = JSEnvResolver.detectPackageManager(projectPath: projectPath)
        guard let executable = JSEnvResolver.packageManagerPath(packageManager) else {
            return JSScriptResult(
                exitCode: -1,
                stdout: "",
                stderr: "Package manager '\(packageManager.rawValue)' not found",
                duration: 0
            )
        }

        return await execute(
            executable: executable,
            arguments: ["run", script] + arguments,
            projectPath: projectPath
        )
    }

    public func runExecutable(
        _ executableName: String,
        arguments: [String],
        projectPath: String
    ) async -> JSScriptResult {
        guard let executable = localBin(executableName, projectPath: projectPath)
            ?? JSEnvResolver.findCommand(executableName) else {
            return JSScriptResult(
                exitCode: -1,
                stdout: "",
                stderr: "\(executableName) not found",
                duration: 0
            )
        }

        return await execute(
            executable: executable,
            arguments: arguments,
            projectPath: projectPath
        )
    }

    public func cancel() {
        guard let currentProcess, currentProcess.isRunning else { return }
        currentProcess.terminate()
        self.currentProcess = nil
    }

    private func execute(
        executable: String,
        arguments: [String],
        projectPath: String
    ) async -> JSScriptResult {
        cancel()

        let start = Date()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: projectPath)

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        currentProcess = process

        let stdoutBuffer = ProcessOutputBuffer()
        let stderrBuffer = ProcessOutputBuffer()
        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            stdoutBuffer.append(handle.availableData)
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            stderrBuffer.append(handle.availableData)
        }

        let exitCode: Int32
        do {
            exitCode = try await Self.runAndWait(process)
        } catch {
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            currentProcess = nil
            return JSScriptResult(
                exitCode: -1,
                stdout: "",
                stderr: error.localizedDescription,
                duration: Date().timeIntervalSince(start)
            )
        }

        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil

        stdoutBuffer.append(stdoutPipe.fileHandleForReading.readDataToEndOfFile())
        stderrBuffer.append(stderrPipe.fileHandleForReading.readDataToEndOfFile())

        let stdout = String(data: stdoutBuffer.data(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrBuffer.data(), encoding: .utf8) ?? ""
        currentProcess = nil

        return JSScriptResult(
            exitCode: exitCode,
            stdout: stdout,
            stderr: stderr,
            duration: Date().timeIntervalSince(start)
        )
    }

    private nonisolated static func runAndWait(_ process: Process) async throws -> Int32 {
        try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { terminatedProcess in
                continuation.resume(returning: terminatedProcess.terminationStatus)
            }
            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                continuation.resume(throwing: error)
            }
        }
    }

    private func localBin(_ name: String, projectPath: String) -> String? {
        let path = URL(fileURLWithPath: projectPath)
            .appendingPathComponent("node_modules/.bin")
            .appendingPathComponent(name)
            .path
        return FileManager.default.isExecutableFile(atPath: path) ? path : nil
    }
}
