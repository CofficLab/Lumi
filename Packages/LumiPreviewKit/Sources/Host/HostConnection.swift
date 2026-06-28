import Foundation
import os
import SuperLogKit

public extension LumiPreviewFacade {

    // MARK: - 协议

    /// 主进程持有的子进程连接抽象。
    ///
    /// 设计要点：
    /// - 每条 `HostCommand` 经 `send(_:)` 异步发出，等待对应 `HostResponse`。
    /// - 服务端事件（如 `frameProduced`）通过 `events` 异步序列广播。
    /// - 实现需保证 stdin/stdout 的全双工独立运行。
    protocol HostConnection: AnyObject, Sendable {
        var events: AsyncStream<HostEvent> { get }
        var processID: Int32 { get async }
        var isRunning: Bool { get async }

        @discardableResult
        func send(_ command: HostCommand) async throws -> HostResponse

        func terminate() async
    }

    // MARK: - 错误

    enum HostConnectionError: Error, LocalizedError, Equatable {
        case launchFailed(String)
        case alreadyTerminated
        case writeFailed
        case timedOut

        public var errorDescription: String? {
            switch self {
            case .launchFailed(let m): return "Inline host failed to launch: \(m)"
            case .alreadyTerminated: return "Inline host has already terminated."
            case .writeFailed: return "Failed to write to inline host stdin."
            case .timedOut: return "Inline host did not respond in time."
            }
        }
    }

    // MARK: - 进程实现

    /// 基于 `Process` + 管道的 `HostConnection` 实现。
    final class ProcessHostConnection: HostConnection, SuperLog, @unchecked Sendable {
        private nonisolated static let logger = Logger(
            subsystem: "com.coffic.lumi",
            category: "LumiPreviewKit.HostConnection"
        )

        // MARK: 属性

        private let process: Process
        private let stdin: FileHandle
        private let stdout: FileHandle
        private let stderr: FileHandle

        private let encoder: JSONEncoder = {
            let encoder = JSONEncoder()
            encoder.outputFormatting = []
            return encoder
        }()
        private let decoder = JSONDecoder()

        private let lock = NSLock()
        private var nextRequestID: UInt64 = 0
        private var pendingRequests: [UInt64: CheckedContinuation<HostResponse, Error>] = [:]
        private var stdoutBuffer = Data()
        private var stderrBuffer = Data()

        private let eventContinuation: AsyncStream<HostEvent>.Continuation
        public let events: AsyncStream<HostEvent>

        // MARK: 初始化

        public static func launch(executableURL: URL) throws -> ProcessHostConnection {
            guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
                throw HostConnectionError.launchFailed("Not an executable file: \(executableURL.path)")
            }

            let process = Process()
            process.executableURL = executableURL
            process.environment = Self.hostEnvironment(executableURL: executableURL)

            let stdin = Pipe()
            let stdout = Pipe()
            let stderr = Pipe()
            process.standardInput = stdin
            process.standardOutput = stdout
            process.standardError = stderr

            do {
                try process.run()
            } catch {
                throw HostConnectionError.launchFailed(error.localizedDescription)
            }

            return ProcessHostConnection(
                process: process,
                stdin: stdin.fileHandleForWriting,
                stdout: stdout.fileHandleForReading,
                stderr: stderr.fileHandleForReading
            )
        }

        private static func hostEnvironment(executableURL: URL) -> [String: String] {
            var environment = ProcessInfo.processInfo.environment
            if let profilePath = environment["LLVM_PROFILE_FILE"],
               !profilePath.isEmpty {
                environment["LLVM_PROFILE_FILE"] = hostProfilePath(from: URL(fileURLWithPath: profilePath))
                return environment
            }

            let buildDirectory = executableURL.deletingLastPathComponent()
            let codecovDirectory = buildDirectory.appendingPathComponent("codecov", isDirectory: true)
            if FileManager.default.fileExists(atPath: codecovDirectory.path) {
                environment["LLVM_PROFILE_FILE"] = codecovDirectory
                    .appendingPathComponent("LumiPreviewHostApp-inline-host-%p.profraw")
                    .path
            }
            return environment
        }

        private static func hostProfilePath(from url: URL) -> String {
            let basename = url.deletingPathExtension().lastPathComponent
            let ext = url.pathExtension.isEmpty ? "profraw" : url.pathExtension
            let filename = "\(basename)-inline-host-%p.\(ext)"
            return url
                .deletingLastPathComponent()
                .appendingPathComponent(filename)
                .path
        }

        private init(
            process: Process,
            stdin: FileHandle,
            stdout: FileHandle,
            stderr: FileHandle
        ) {
            self.process = process
            self.stdin = stdin
            self.stdout = stdout
            self.stderr = stderr

            var continuationCapture: AsyncStream<HostEvent>.Continuation!
            self.events = AsyncStream { continuation in
                continuationCapture = continuation
            }
            self.eventContinuation = continuationCapture

            installStdoutReader()
            installStderrReader()
            installTerminationHandler()
        }

        // MARK: 公开方法

        public var processID: Int32 {
            get async { process.processIdentifier }
        }

        public var isRunning: Bool {
            get async { process.isRunning }
        }

        @discardableResult
        public func send(_ command: HostCommand) async throws -> HostResponse {
            guard process.isRunning else {
                throw HostConnectionError.alreadyTerminated
            }

            let id = nextID()
            let request = HostRequest(requestID: id, command: command)
            let data = try encoder.encode(request)

            return try await withCheckedThrowingContinuation { continuation in
                lock.lock()
                pendingRequests[id] = continuation
                lock.unlock()

                do {
                    var line = data
                    line.append(0x0A)
                    try stdin.write(contentsOf: line)
                } catch {
                    lock.lock()
                    pendingRequests.removeValue(forKey: id)
                    lock.unlock()
                    continuation.resume(throwing: HostConnectionError.writeFailed)
                }
            }
        }

        public func terminate() async {
            try? stdin.close()
            for _ in 0..<20 where process.isRunning {
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
            if process.isRunning {
                process.terminate()
                process.waitUntilExit()
            }
            failPendingRequests(with: .alreadyTerminated)
            eventContinuation.finish()
        }

        // MARK: 私有方法

        private func nextID() -> UInt64 {
            lock.lock()
            defer { lock.unlock() }
            nextRequestID &+= 1
            return nextRequestID
        }

        private func installStdoutReader() {
            stdout.readabilityHandler = { [weak self] handle in
                guard let self else { return }
                let data = handle.availableData
                if data.isEmpty {
                    handle.readabilityHandler = nil
                    return
                }
                self.appendStdout(data)
            }
        }

        private func installStderrReader() {
            stderr.readabilityHandler = { [weak self] handle in
                guard let self else { return }
                let data = handle.availableData
                if data.isEmpty {
                    handle.readabilityHandler = nil
                    self.flushStderrRemainder()
                    return
                }
                self.appendStderr(data)
            }
        }

        private func installTerminationHandler() {
            process.terminationHandler = { [weak self] _ in
                guard let self else { return }
                self.failPendingRequests(with: .alreadyTerminated)
                self.eventContinuation.finish()
            }
        }

        private func appendStdout(_ data: Data) {
            lock.lock()
            stdoutBuffer.append(data)
            let lines = drainStdoutLines()
            lock.unlock()
            for line in lines {
                process(line: line)
            }
        }

        private func drainStdoutLines() -> [Data] {
            var lines: [Data] = []
            while let newlineIndex = stdoutBuffer.firstIndex(of: 0x0A) {
                let lineData = Data(stdoutBuffer.prefix(upTo: newlineIndex))
                stdoutBuffer.removeSubrange(...newlineIndex)
                if !lineData.isEmpty {
                    lines.append(lineData)
                }
            }
            return lines
        }

        private func appendStderr(_ data: Data) {
            lock.lock()
            stderrBuffer.append(data)
            let lines = drainStderrLines()
            lock.unlock()
            for line in lines {
                logHostStderr(line)
            }
        }

        private func drainStderrLines() -> [Data] {
            var lines: [Data] = []
            while let newlineIndex = stderrBuffer.firstIndex(of: 0x0A) {
                let lineData = Data(stderrBuffer.prefix(upTo: newlineIndex))
                stderrBuffer.removeSubrange(...newlineIndex)
                if !lineData.isEmpty {
                    lines.append(lineData)
                }
            }
            return lines
        }

        private func flushStderrRemainder() {
            lock.lock()
            let data = stderrBuffer
            stderrBuffer.removeAll()
            lock.unlock()
            guard !data.isEmpty else { return }
            logHostStderr(data)
        }

        private func logHostStderr(_ data: Data) {
            let message = String(data: data, encoding: .utf8) ?? "<non-utf8 stderr \(data.count) bytes>"
            Self.logger.info("\(self.t)📝 inline host stderr pid=\(self.process.processIdentifier, privacy: .public): \(message, privacy: .public)")
        }

        private func process(line data: Data) {
            guard let outbound = try? decoder.decode(HostOutbound.self, from: data) else {
                return
            }
            switch outbound {
            case let .response(requestID, payload):
                deliver(response: payload, for: requestID)
            case let .event(event):
                eventContinuation.yield(event)
            }
        }

        private func deliver(response: HostResponse, for requestID: UInt64) {
            lock.lock()
            let continuation = pendingRequests.removeValue(forKey: requestID)
            lock.unlock()
            continuation?.resume(returning: response)
        }

        private func failPendingRequests(with error: HostConnectionError) {
            lock.lock()
            let continuations = pendingRequests
            pendingRequests.removeAll()
            lock.unlock()
            for (_, continuation) in continuations {
                continuation.resume(throwing: error)
            }
        }
    }
}
