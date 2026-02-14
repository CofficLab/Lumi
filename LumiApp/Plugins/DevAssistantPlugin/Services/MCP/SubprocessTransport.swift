
import Foundation
import MCP
import OSLog
import MagicKit
import Logging

/// A Transport that communicates with a subprocess via Stdio
actor SubprocessTransport: Transport, SuperLog {
    nonisolated let logger: Logging.Logger
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
        // Resolve executable path
        var executablePath = resolveExecutablePath(for: command)
        
        // If command is npx or npm, we need to ensure node is in PATH
        // or resolve npx absolute path.
        // Also, for npx, we might want to check if it's a node script wrapper
        // and ensure the environment has correct PATH.
        
        // Special handling for node/npx environment
        var env = ProcessInfo.processInfo.environment
        for (key, value) in environment {
            env[key] = value
        }
        
        // Try to find node path to append to PATH if not present
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
        
        // Start monitoring stdout
        Task.detached { [weak self] in
            guard let self = self else { return }
            await self.monitorOutput(pipe: stdout)
        }
        
        // Start monitoring stderr (log it)
        Task.detached {
            await self.monitorError(pipe: stderr)
        }
        
        do {
            try process.run()
        } catch {
            os_log(.error, "Failed to run process \(executablePath): \(error.localizedDescription)")
            throw error
        }
    }
    
    func disconnect() async {
        process?.terminate()
        process = nil
        messageContinuation.finish()
    }
    
    func send(_ data: Data) async throws {
        guard let stdin = stdinPipe else { return }
        
        // Write data to stdin
        try stdin.fileHandleForWriting.write(contentsOf: data)
        
        // Ensure newline for JSON-RPC over Stdio
        // If the data doesn't end with newline, append it.
        // Explicitly use UTF-8 string conversion to check suffix
        if let str = String(data: data, encoding: .utf8), !str.hasSuffix("\n") {
             if let newlineData = "\n".data(using: .utf8) {
                try stdin.fileHandleForWriting.write(contentsOf: newlineData)
             }
        }
    }
    
    func receive() -> AsyncThrowingStream<Data, Error> {
        return messageStream
    }
    
    // MARK: - Helpers
    
    private func monitorOutput(pipe: Pipe) async {
        let handle = pipe.fileHandleForReading
        
        // Read line by line
        do {
            for try await line in handle.bytes.lines {
                // Each line is a message
                if let data = line.data(using: .utf8) {
                    messageContinuation.yield(data)
                }
            }
        } catch {
             os_log(.error, "Error reading from stdout: \(error.localizedDescription)")
             messageContinuation.finish(throwing: error)
             return
        }
        
        // Stream ended
        messageContinuation.finish()
    }
    
    nonisolated private func monitorError(pipe: Pipe) async {
        let handle = pipe.fileHandleForReading
        do {
            for try await line in handle.bytes.lines {
                os_log(.debug, "\(Self.t)[MCP Stderr] \(line)")
            }
        } catch {
             os_log(.error, "Error reading from stderr: \(error.localizedDescription)")
        }
    }
    
    nonisolated private func resolveExecutablePath(for command: String) -> String {
        if command.hasPrefix("/") { return command }
        
        // Use a more comprehensive shell environment to resolve path
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        // Use login shell to ensure PATH is loaded correctly (e.g. from .zshrc)
        process.arguments = ["-l", "-c", "which \(command)"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        // Also capture stderr to debug resolution failures
        let errPipe = Pipe()
        process.standardError = errPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty {
                // Check if the path actually exists
                if FileManager.default.fileExists(atPath: path) {
                    return path
                }
            }
        } catch {
            os_log(.error, "Failed to resolve command \(command): \(error.localizedDescription)")
        }
        
        // Common fallback paths for Homebrew and system
        let commonPaths = [
            "/opt/homebrew/bin/\(command)",
            "/usr/local/bin/\(command)",
            "/usr/bin/\(command)",
            "/bin/\(command)"
        ]
        
        for path in commonPaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        // Final fallback
        return "/usr/bin/\(command)"
    }
}
