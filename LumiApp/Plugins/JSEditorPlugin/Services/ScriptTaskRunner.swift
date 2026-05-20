import Foundation
import MagicKit

actor ScriptTaskRunner: SuperLog {
    nonisolated static let emoji = "▶️"

    private var currentProcess: Process?

    func runScript(
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

    func runExecutable(
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

    func cancel() {
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

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            currentProcess = nil
            return JSScriptResult(
                exitCode: -1,
                stdout: "",
                stderr: error.localizedDescription,
                duration: Date().timeIntervalSince(start)
            )
        }

        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        currentProcess = nil

        return JSScriptResult(
            exitCode: process.terminationStatus,
            stdout: stdout,
            stderr: stderr,
            duration: Date().timeIntervalSince(start)
        )
    }

    private func localBin(_ name: String, projectPath: String) -> String? {
        let path = URL(fileURLWithPath: projectPath)
            .appendingPathComponent("node_modules/.bin")
            .appendingPathComponent(name)
            .path
        return FileManager.default.isExecutableFile(atPath: path) ? path : nil
    }
}
