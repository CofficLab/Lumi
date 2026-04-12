import Foundation
import Combine
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

    private final class LockedExecutionProgress: @unchecked Sendable {
        private let lock = NSLock()
        private var totalBytes = 0
        private var totalLines = 0
        private var outputTail = ""
        private static let maxTailChars = 120

        private static func sanitizeStatusPreviewLine(_ raw: String) -> String {
            // 去掉 ANSI 控制序列（颜色、光标控制等）
            let ansiStripped = raw.replacingOccurrences(
                of: #"\u{001B}\[[0-9;?]*[ -/]*[@-~]"#,
                with: "",
                options: .regularExpression
            )

            // 去掉不可见控制字符（保留普通可见字符与空格）
            let scalars = ansiStripped.unicodeScalars.filter { scalar in
                if scalar == "\t" || scalar == " " { return true }
                return scalar.value >= 0x20 && scalar.value != 0x7F
            }
            let cleaned = String(String.UnicodeScalarView(scalars))
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if cleaned.count <= Self.maxTailChars {
                return cleaned
            }
            return String(cleaned.suffix(Self.maxTailChars))
        }

        func append(_ chunk: Data) {
            lock.lock()
            totalBytes += chunk.count
            totalLines += chunk.reduce(0) { $1 == 0x0A ? $0 + 1 : $0 }
            if let text = String(data: chunk, encoding: .utf8), !text.isEmpty {
                outputTail.append(text)
                if outputTail.count > Self.maxTailChars {
                    outputTail = String(outputTail.suffix(Self.maxTailChars))
                }
                let segments = outputTail.split(whereSeparator: { $0 == "\n" || $0 == "\r" })
                let latestNonEmpty = segments.reversed().first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
                let candidate = latestNonEmpty.map(String.init) ?? outputTail
                outputTail = Self.sanitizeStatusPreviewLine(candidate)
            }
            lock.unlock()
        }

        func snapshot(elapsedSeconds: Int) -> ShellExecutionProgressSnapshot {
            lock.lock()
            let snapshot = ShellExecutionProgressSnapshot(
                elapsedSeconds: max(0, elapsedSeconds),
                totalBytes: totalBytes,
                totalLines: totalLines,
                latestOutputPreview: outputTail
            )
            lock.unlock()
            return snapshot
        }
    }

    private actor ActiveExecutionProgressStore {
        private var progress: LockedExecutionProgress?
        private var startedAt: Date?

        func set(progress: LockedExecutionProgress, startedAt: Date) {
            self.progress = progress
            self.startedAt = startedAt
        }

        func clear() {
            progress = nil
            startedAt = nil
        }

        func snapshot() -> ShellExecutionProgressSnapshot? {
            guard let progress, let startedAt else { return nil }
            let elapsed = Int(Date().timeIntervalSince(startedAt))
            return progress.snapshot(elapsedSeconds: elapsed)
        }
    }

    // MARK: - Logger

    nonisolated static let emoji = "🐚"
    nonisolated static let verbose: Bool = false
    // MARK: - Singleton

    static let shared = ShellService()

    private init() {
        if Self.verbose {
            AgentCoreToolsPlugin.logger.info("\(self.t) Shell 服务已初始化（单例）")
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

    private let activeProgressStore = ActiveExecutionProgressStore()

    func progressSnapshot() async -> ShellExecutionProgressSnapshot? {
        await activeProgressStore.snapshot()
    }

    func execute(_ command: String) async throws -> String {
        if Self.verbose {
            AgentCoreToolsPlugin.logger.info("\(self.t) 执行命令: \n\(command)")
        }
        // Capture mutable state on MainActor
        let workingDirectory = await MainActor.run { self.currentDirectory }
        if Self.verbose {
            AgentCoreToolsPlugin.logger.info("\(self.t) workingDirectory: \(workingDirectory)")
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

        let startedAt = Date()
        let executionProgress = LockedExecutionProgress()
        await activeProgressStore.set(progress: executionProgress, startedAt: startedAt)

        let result: String
        do {
            result = try await Task.detached(priority: .userInitiated) {
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
                    executionProgress.append(chunk)
                    if Self.verbose {
                        AgentCoreToolsPlugin.logger.info("\(self.t) stdout +\(chunk.count) bytes")
                    }
                }
            }
            stderrHandle.readabilityHandler = { handle in
                let chunk = handle.availableData
                if !chunk.isEmpty {
                    stderrBuffer.append(chunk)
                    executionProgress.append(chunk)
                    if Self.verbose {
                        AgentCoreToolsPlugin.logger.info("\(self.t) stderr +\(chunk.count) bytes")
                    }
                }
            }

            try process.run()
            if Self.verbose {
                AgentCoreToolsPlugin.logger.info("\(self.t) process started pid=\(process.processIdentifier)")
            }

            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    process.terminationHandler = { _ in
                        continuation.resume()
                    }
                }
            } onCancel: {
                if process.isRunning {
                    process.terminate()
                }
            }

            // 清理 handler，确保不再回调
            stdoutHandle.readabilityHandler = nil
            stderrHandle.readabilityHandler = nil

            // 读取最后残留的数据（若有）
            let finalStdout = stdoutHandle.availableData
            if !finalStdout.isEmpty {
                stdoutBuffer.append(finalStdout)
                executionProgress.append(finalStdout)
                if Self.verbose {
                    AgentCoreToolsPlugin.logger.info("\(self.t) stdout(final) +\(finalStdout.count) bytes")
                }
            }
            let finalStderr = stderrHandle.availableData
            if !finalStderr.isEmpty {
                stderrBuffer.append(finalStderr)
                executionProgress.append(finalStderr)
                if Self.verbose {
                    AgentCoreToolsPlugin.logger.info("\(self.t) stderr(final) +\(finalStderr.count) bytes")
                }
            }

            let stdoutData = stdoutBuffer.snapshot()
            let stderrData = stderrBuffer.snapshot()
            let output = String(data: stdoutData, encoding: .utf8) ?? ""
            let errorOutput = String(data: stderrData, encoding: .utf8) ?? ""

            if Task.isCancelled {
                throw CancellationError()
            }

            if Self.verbose {
                let duration = Date().timeIntervalSince(startedAt)
                AgentCoreToolsPlugin.logger.info("\(self.t) exitCode=\(process.terminationStatus) signal=\(process.terminationReason.rawValue) duration=\(String(format: "%.3f", duration))s")
                AgentCoreToolsPlugin.logger.info("\(self.t) stdout=\(stdoutData.count) bytes stderr=\(stderrData.count) bytes")

                let outputPreview = output.count > 400 ? String(output.prefix(400)) + "…" : output
                let errorPreview = errorOutput.count > 400 ? String(errorOutput.prefix(400)) + "…" : errorOutput
                AgentCoreToolsPlugin.logger.info("\(self.t) stdout preview:\n\(outputPreview)")
                if !errorOutput.isEmpty {
                    AgentCoreToolsPlugin.logger.info("\(self.t) stderr preview:\n\(errorPreview)")
                }
            }

            return output + (errorOutput.isEmpty ? "" : "\nError:\n\(errorOutput)")
            }.value
        } catch {
            await activeProgressStore.clear()
            throw error
        }
        await activeProgressStore.clear()

        await MainActor.run {
            currentOutput = result
            outputPublisher.send(result)
        }
        return result
    }
}

struct ShellExecutionProgressSnapshot: Sendable {
    let elapsedSeconds: Int
    let totalBytes: Int
    let totalLines: Int
    let latestOutputPreview: String
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
