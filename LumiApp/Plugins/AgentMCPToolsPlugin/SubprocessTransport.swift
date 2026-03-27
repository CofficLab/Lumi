import Foundation
import MCP
import MagicKit
import Logging

/// 通过标准输入输出与子进程通信的传输层
actor SubprocessTransport: Transport, SuperLog {
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
    var logger: Logging.Logger

    nonisolated static let emoji = "📟"
    nonisolated static let verbose = true

    let command: String
    let arguments: [String]
    let environment: [String: String]

    private var process: Process?
    private var stdinPipe: Pipe?

    private let messageStream: AsyncThrowingStream<Data, Error>
    private let messageContinuation: AsyncThrowingStream<Data, Error>.Continuation

    init(command: String, arguments: [String], environment: [String: String] = [:], logger: Logging.Logger? = nil) {
        self.command = command
        self.arguments = arguments
        self.environment = environment
        self.logger = logger ?? Logging.Logger(label: "Lumi.SubprocessTransport")

        var continuation: AsyncThrowingStream<Data, Error>.Continuation!
        self.messageStream = AsyncThrowingStream { continuation = $0 }
        self.messageContinuation = continuation
    }

    func connect() async throws {
        let executablePath = resolveExecutablePath(for: command)

        var env = ProcessInfo.processInfo.environment
        for (key, value) in environment {
            env[key] = value
        }

        if let nodePath = resolveExecutablePath(for: "node").components(separatedBy: "/").dropLast().joined(separator: "/").nilIfEmpty {
            let currentPath = env["PATH"] ?? ""
            if !currentPath.contains(nodePath) {
                env["PATH"] = "\(nodePath):\(currentPath)"
            }
        }

        if Self.verbose {
            AgentMCPToolsPlugin.logger.info("\(Self.t)启动子进程: \(executablePath) \(self.arguments.joined(separator: " "))")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.environment = env

        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()

        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr

        self.stdinPipe = stdin
        self.process = process

        Task.detached { [weak self] in
            guard let self else { return }
            await self.monitorOutput(pipe: stdout)
        }

        Task.detached {
            await self.monitorError(pipe: stderr)
        }

        do {
            try process.run()
            if Self.verbose {
                AgentMCPToolsPlugin.logger.info("\(Self.t)✅ 子进程已启动: \(executablePath)")
            }
        } catch {
            AgentMCPToolsPlugin.logger.error("\(Self.t)❌ 运行进程失败 \(executablePath): \(error)")
            throw error
        }
    }

    func disconnect() async {
        if Self.verbose {
            AgentMCPToolsPlugin.logger.info("\(Self.t)停止子进程: \(self.command)")
        }
        process?.terminate()
        process = nil
        messageContinuation.finish()
    }

    func send(_ data: Data) async throws {
        guard let stdin = stdinPipe else { return }

        try stdin.fileHandleForWriting.write(contentsOf: data)

        if let str = String(data: data, encoding: .utf8), !str.hasSuffix("\n") {
            if let newlineData = "\n".data(using: .utf8) {
                try stdin.fileHandleForWriting.write(contentsOf: newlineData)
            }
        }

        if Self.verbose {
            if let str = String(data: data, encoding: .utf8) {
                AgentMCPToolsPlugin.logger.info("\(Self.t)📤 已发送: \(str.prefix(200))")
            }
        }
    }

    func receive() -> AsyncThrowingStream<Data, Error> {
        return messageStream
    }

    private func monitorOutput(pipe: Pipe) async {
        let handle = pipe.fileHandleForReading

        do {
            for try await line in handle.bytes.lines {
                if let data = line.data(using: .utf8) {
                    if Self.verbose {
                        if let str = String(data: data, encoding: .utf8) {
                            AgentMCPToolsPlugin.logger.info("\(Self.t)📥 已接收: \(str.prefix(200))")
                        }
                    }
                    messageContinuation.yield(data)
                }
            }
        } catch {
            AgentMCPToolsPlugin.logger.error("\(Self.t)❌ 从 stdout 读取失败: \(error.localizedDescription)")
            messageContinuation.finish(throwing: error)
            return
        }

        messageContinuation.finish()
    }

    nonisolated private func monitorError(pipe: Pipe) async {
        let handle = pipe.fileHandleForReading
        do {
            for try await line in handle.bytes.lines {
                if Self.verbose {
                    AgentMCPToolsPlugin.logger.info("\(Self.t)[MCP Stderr] \(line)")
                }
            }
        } catch {
            AgentMCPToolsPlugin.logger.error("\(Self.t)❌ 从 stderr 读取失败: \(error.localizedDescription)")
        }
    }

    nonisolated private func resolveExecutablePath(for command: String) -> String {
        if command.hasPrefix("/") { return command }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "which \(command)"]

        let pipe = Pipe()
        process.standardOutput = pipe

        let errPipe = Pipe()
        process.standardError = errPipe

        do {
            try process.run()
            let buffer = LockedDataBuffer()
            let handle = pipe.fileHandleForReading
            handle.readabilityHandler = { h in
                let chunk = h.availableData
                if !chunk.isEmpty { buffer.append(chunk) }
            }

            let semaphore = DispatchSemaphore(value: 0)
            process.terminationHandler = { _ in
                semaphore.signal()
            }
            semaphore.wait()

            handle.readabilityHandler = nil
            let final = handle.availableData
            if !final.isEmpty { buffer.append(final) }
            if let path = String(data: buffer.snapshot(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty {
                if FileManager.default.fileExists(atPath: path) {
                    if Self.verbose {
                        AgentMCPToolsPlugin.logger.info("\(Self.t)解析命令 '\(command)' 为: \(path)")
                    }
                    return path
                }
            }
        } catch {
            AgentMCPToolsPlugin.logger.error("\(Self.t)❌ 解析命令失败 \(command): \(error.localizedDescription)")
        }

        let commonPaths = [
            "/opt/homebrew/bin/\(command)",
            "/usr/local/bin/\(command)",
            "/usr/bin/\(command)",
            "/bin/\(command)"
        ]

        for path in commonPaths {
            if FileManager.default.fileExists(atPath: path) {
                if Self.verbose {
                    AgentMCPToolsPlugin.logger.info("\(Self.t)解析命令 '\(command)' 为备用路径: \(path)")
                }
                return path
            }
        }

        if Self.verbose {
            AgentMCPToolsPlugin.logger.info("\(Self.t)⚠️ 使用最终备用路径命令 '\(command)': /usr/bin/\(command)")
        }
        return "/usr/bin/\(command)"
    }
}

