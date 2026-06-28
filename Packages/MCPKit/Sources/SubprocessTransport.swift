import Foundation
import SuperLogKit
import Logging
import MCP

public actor SubprocessTransport: Transport, SuperLog {
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

    public let command: String
    public let arguments: [String]
    public let environment: [String: String]

    public let logger: Logging.Logger
    private var process: Process?
    private var stdinPipe: Pipe?

    private let messageStream: AsyncThrowingStream<Data, Error>
    private let messageContinuation: AsyncThrowingStream<Data, Error>.Continuation

    public init(command: String, arguments: [String], environment: [String: String] = [:], logger: Logging.Logger? = nil) {
        self.command = command
        self.arguments = arguments
        self.environment = environment
        self.logger = logger ?? Logging.Logger(label: "Lumi.MCPKit.SubprocessTransport")

        var continuation: AsyncThrowingStream<Data, Error>.Continuation!
        self.messageStream = AsyncThrowingStream { continuation = $0 }
        self.messageContinuation = continuation
    }

    public func connect() async throws {
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

        Task.detached { [logger] in
            await Self.monitorError(pipe: stderr, logger: logger)
        }

        do {
            try process.run()
        } catch {
            logger.error("\(Self.t)Failed to run MCP subprocess \(executablePath): \(error.localizedDescription)")
            throw error
        }
    }

    public func disconnect() async {
        process?.terminate()
        process = nil
        messageContinuation.finish()
    }

    public func send(_ data: Data) async throws {
        guard let stdin = stdinPipe else { return }

        try stdin.fileHandleForWriting.write(contentsOf: data)

        if let str = String(data: data, encoding: .utf8), !str.hasSuffix("\n"),
           let newlineData = "\n".data(using: .utf8)
        {
            try stdin.fileHandleForWriting.write(contentsOf: newlineData)
        }
    }

    public func receive() -> AsyncThrowingStream<Data, Error> {
        messageStream
    }

    private func monitorOutput(pipe: Pipe) async {
        let handle = pipe.fileHandleForReading

        do {
            for try await line in handle.bytes.lines {
                if let data = line.data(using: .utf8) {
                    messageContinuation.yield(data)
                }
            }
        } catch {
            logger.error("\(Self.t)Failed to read MCP subprocess stdout: \(error.localizedDescription)")
            messageContinuation.finish(throwing: error)
            return
        }

        messageContinuation.finish()
    }

    nonisolated private static func monitorError(pipe: Pipe, logger: Logging.Logger) async {
        let handle = pipe.fileHandleForReading
        do {
            for try await line in handle.bytes.lines {
                logger.debug("\(Self.t)[MCP stderr] \(line)")
            }
        } catch {
            logger.error("\(Self.t)Failed to read MCP subprocess stderr: \(error.localizedDescription)")
        }
    }

    nonisolated private func resolveExecutablePath(for command: String) -> String {
        if command.hasPrefix("/") { return command }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "which \(command)"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            let buffer = LockedDataBuffer()
            let handle = pipe.fileHandleForReading
            handle.readabilityHandler = { handle in
                let chunk = handle.availableData
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
            if let path = String(data: buffer.snapshot(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty,
               FileManager.default.fileExists(atPath: path)
            {
                return path
            }
        } catch {
            // Fall through to common locations.
        }

        let commonPaths = [
            "/opt/homebrew/bin/\(command)",
            "/usr/local/bin/\(command)",
            "/usr/bin/\(command)",
            "/bin/\(command)",
        ]

        for path in commonPaths where FileManager.default.fileExists(atPath: path) {
            return path
        }

        return "/usr/bin/\(command)"
    }
}
