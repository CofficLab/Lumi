import Foundation
import Combine
import OSLog
import MagicKit

/// Shell 服务：负责执行 Shell 命令
///
/// 设计原则：
/// - 不在主线程上运行，所有操作都是异步的
/// - 通过 Combine Publishers 通知状态变化
/// - ViewModel 层负责将状态暴露给 UI
/// - 单例模式，全局共享一个 Shell 服务实例
///
/// 线程安全：此类通过方法内部同步保证线程安全，因此可以安全地在并发代码中使用
class ShellService: SuperLog {
    private final class LockedDataBuffer: @unchecked Sendable {
        private let lock = NSLock()
        private var data = Data()

        func append(_ chunk: Data) {
            lock.lock()
            data.append(chunk)
            lock.unlock()
        }

        func snapshot() -> Data {
            lock.lock()
            let copy = data
            lock.unlock()
            return copy
        }
    }

    // MARK: - Logger

    nonisolated static let emoji = "🐚"
    nonisolated static let verbose = true

    // MARK: - Singleton

    static let shared = ShellService()

    private init() {
        if Self.verbose {
            os_log("\(Self.t)✅ Shell 服务已初始化（单例）")
        }
    }

    // MARK: - Combine Publishers

    /// Shell 输出变化通知
    let outputPublisher = PassthroughSubject<String, Never>()

    /// Shell 运行状态变化通知
    let runningStatePublisher = PassthroughSubject<Bool, Never>()

    // MARK: - Properties

    /// 当前工作目录
    var currentDirectory: String = FileManager.default.homeDirectoryForCurrentUser.path

    /// 当前输出（供同步访问）
    private(set) var currentOutput: String = ""

    /// 是否正在运行（供同步访问）
    private(set) var isRunning: Bool = false

    func execute(_ command: String) async throws -> String {
        if Self.verbose {
            os_log("\(Self.t)🐚 执行命令: \n\(command)")
        }
        // Capture mutable state on MainActor
        let workingDirectory = await MainActor.run { self.currentDirectory }
        if Self.verbose {
            os_log("\(Self.t)📂 workingDirectory: \(workingDirectory)")
        }
        await MainActor.run {
            isRunning = true
            runningStatePublisher.send(true)
        }

        defer {
            Task { @MainActor in
                self.isRunning = false
                self.runningStatePublisher.send(false)
            }
        }

        return try await Task.detached(priority: .userInitiated) {
            let startedAt = Date()
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", command]
            process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)

            var env = ProcessInfo.processInfo.environment
            env["TERM"] = "xterm-256color"
            env["LANG"] = "en_US.UTF-8"
            env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            process.environment = env

            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            let stdoutBuffer = LockedDataBuffer()
            let stderrBuffer = LockedDataBuffer()

            let stdoutHandle = stdoutPipe.fileHandleForReading
            let stderrHandle = stderrPipe.fileHandleForReading

            // 持续 drain stdout/stderr，避免 readDataToEndOfFile + 双 pipe 死锁
            stdoutHandle.readabilityHandler = { handle in
                let chunk = handle.availableData
                if !chunk.isEmpty {
                    stdoutBuffer.append(chunk)
                    if Self.verbose {
                        os_log("\(Self.t)📤 stdout +\(chunk.count) bytes")
                    }
                }
            }
            stderrHandle.readabilityHandler = { handle in
                let chunk = handle.availableData
                if !chunk.isEmpty {
                    stderrBuffer.append(chunk)
                    if Self.verbose {
                        os_log("\(Self.t)📥 stderr +\(chunk.count) bytes")
                    }
                }
            }

            try process.run()
            if Self.verbose {
                os_log("\(Self.t)🚀 process started pid=\(process.processIdentifier)")
            }

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                process.terminationHandler = { _ in
                    continuation.resume()
                }
            }

            // 清理 handler，确保不再回调
            stdoutHandle.readabilityHandler = nil
            stderrHandle.readabilityHandler = nil

            // 读取最后残留的数据（若有）
            let finalStdout = stdoutHandle.availableData
            if !finalStdout.isEmpty {
                stdoutBuffer.append(finalStdout)
                if Self.verbose {
                    os_log("\(Self.t)📤 stdout(final) +\(finalStdout.count) bytes")
                }
            }
            let finalStderr = stderrHandle.availableData
            if !finalStderr.isEmpty {
                stderrBuffer.append(finalStderr)
                if Self.verbose {
                    os_log("\(Self.t)📥 stderr(final) +\(finalStderr.count) bytes")
                }
            }

            let stdoutData = stdoutBuffer.snapshot()
            let stderrData = stderrBuffer.snapshot()
            let output = String(data: stdoutData, encoding: .utf8) ?? ""
            let errorOutput = String(data: stderrData, encoding: .utf8) ?? ""

            if Self.verbose {
                let duration = Date().timeIntervalSince(startedAt)
                os_log("\(Self.t)🧾 exitCode=\(process.terminationStatus) signal=\(process.terminationReason.rawValue) duration=\(String(format: "%.3f", duration))s")
                os_log("\(Self.t)📊 stdout=\(stdoutData.count) bytes stderr=\(stderrData.count) bytes")

                let outputPreview = output.count > 400 ? String(output.prefix(400)) + "…" : output
                let errorPreview = errorOutput.count > 400 ? String(errorOutput.prefix(400)) + "…" : errorOutput
                os_log("\(Self.t)📝 stdout preview:\n\(outputPreview)")
                if !errorOutput.isEmpty {
                    os_log("\(Self.t)📝 stderr preview:\n\(errorPreview)")
                }
            }

            return output + (errorOutput.isEmpty ? "" : "\nError:\n\(errorOutput)")
        }.value
    }
}

// MARK: - Sendable Conformance

extension ShellService: @unchecked Sendable {
    @MainActor
    func updateWorkingDirectory(_ path: String) {
        var targetPath = path
        if path.hasPrefix("~") {
            targetPath = (path as NSString).expandingTildeInPath
        }

        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: targetPath, isDirectory: &isDir), isDir.boolValue {
            self.currentDirectory = targetPath
        }
    }
}
