import Foundation
import MCP
import OSLog
import MagicKit
import Logging

/// 通过标准输入输出与子进程通信的传输层
actor SubprocessTransport: Transport, SuperLog {
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
        // 解析可执行文件路径
        let executablePath = resolveExecutablePath(for: command)
        
        // 如果是 npx 或 npm，需要确保 node 在 PATH 中
        // 或者解析 npx 的绝对路径
        // 对于 npx，可能需要检查是否是 node 脚本包装器
        // 并确保环境变量有正确的 PATH
        
        // node/npx 环境的特殊处理
        var env = ProcessInfo.processInfo.environment
        for (key, value) in environment {
            env[key] = value
        }
        
        // 尝试查找 node 路径以添加到 PATH（如果不存在）
        if let nodePath = resolveExecutablePath(for: "node").components(separatedBy: "/").dropLast().joined(separator: "/").nilIfEmpty {
             let currentPath = env["PATH"] ?? ""
             if !currentPath.contains(nodePath) {
                 env["PATH"] = "\(nodePath):\(currentPath)"
             }
        }
        
        if Self.verbose {
            os_log("\(Self.t)启动子进程: \(executablePath) \(self.arguments.joined(separator: " "))")
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
        
        // 开始监控 stdout
        Task.detached { [weak self] in
            guard let self = self else { return }
            await self.monitorOutput(pipe: stdout)
        }
        
        // 开始监控 stderr（记录日志）
        Task.detached {
            await self.monitorError(pipe: stderr)
        }
        
        do {
            try process.run()
            if Self.verbose {
                os_log("\(Self.t)✅ 子进程已启动: \(executablePath)")
            }
        } catch {
            os_log(.error, "\(Self.t)❌ 运行进程失败 \(executablePath): \(error)")
            throw error
        }
    }
    
    func disconnect() async {
        if Self.verbose {
            os_log("\(Self.t)停止子进程: \(self.command)")
        }
        process?.terminate()
        process = nil
        messageContinuation.finish()
    }
    
    func send(_ data: Data) async throws {
        guard let stdin = stdinPipe else { return }
        
        // 写入数据到 stdin
        try stdin.fileHandleForWriting.write(contentsOf: data)
        
        // 为 JSON-RPC over Stdio 确保换行
        // 如果数据不以换行符结尾，添加它
        // 显式使用 UTF-8 字符串转换来检查后缀
        if let str = String(data: data, encoding: .utf8), !str.hasSuffix("\n") {
             if let newlineData = "\n".data(using: .utf8) {
                try stdin.fileHandleForWriting.write(contentsOf: newlineData)
             }
        }
        
        if Self.verbose {
            if let str = String(data: data, encoding: .utf8) {
                os_log("\(Self.t)📤 已发送: \(str.prefix(200))")
            }
        }
    }
    
    func receive() -> AsyncThrowingStream<Data, Error> {
        return messageStream
    }
    
    // MARK: - 辅助方法
    
    private func monitorOutput(pipe: Pipe) async {
        let handle = pipe.fileHandleForReading
        
        // 逐行读取
        do {
            for try await line in handle.bytes.lines {
                // 每一行都是一个消息
                if let data = line.data(using: .utf8) {
                    if Self.verbose {
                        if let str = String(data: data, encoding: .utf8) {
                            os_log("\(Self.t)📥 已接收: \(str.prefix(200))")
                        }
                    }
                    messageContinuation.yield(data)
                }
            }
        } catch {
             os_log(.error, "\(Self.t)❌ 从 stdout 读取失败: \(error.localizedDescription)")
             messageContinuation.finish(throwing: error)
             return
        }
        
        // 流结束
        messageContinuation.finish()
    }
    
    nonisolated private func monitorError(pipe: Pipe) async {
        let handle = pipe.fileHandleForReading
        do {
            for try await line in handle.bytes.lines {
                if Self.verbose {
                    os_log("\(Self.t)[MCP Stderr] \(line)")
                }
            }
        } catch {
             os_log(.error, "\(Self.t)❌ 从 stderr 读取失败: \(error.localizedDescription)")
        }
    }
    
    nonisolated private func resolveExecutablePath(for command: String) -> String {
        if command.hasPrefix("/") { return command }
        
        // 使用更全面的 shell 环境来解析路径
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        // 使用登录 shell 确保 PATH 正确加载（例如从 .zshrc）
        process.arguments = ["-l", "-c", "which \(command)"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        // 同时捕获 stderr 以调试解析失败
        let errPipe = Pipe()
        process.standardError = errPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty {
                // 检查路径是否实际存在
                if FileManager.default.fileExists(atPath: path) {
                    if Self.verbose {
                        os_log("\(Self.t)解析命令 '\(command)' 为: \(path)")
                    }
                    return path
                }
            }
        } catch {
            os_log(.error, "\(Self.t)❌ 解析命令失败 \(command): \(error.localizedDescription)")
        }
        
        // Homebrew 和系统的常见备用路径
        let commonPaths = [
            "/opt/homebrew/bin/\(command)",
            "/usr/local/bin/\(command)",
            "/usr/bin/\(command)",
            "/bin/\(command)"
        ]
        
        for path in commonPaths {
            if FileManager.default.fileExists(atPath: path) {
                if Self.verbose {
                    os_log("\(Self.t)解析命令 '\(command)' 为备用路径: \(path)")
                }
                return path
            }
        }
        
        // 最终备用
        if Self.verbose {
            os_log("\(Self.t)⚠️ 使用最终备用路径命令 '\(command)': /usr/bin/\(command)")
        }
        return "/usr/bin/\(command)"
    }
}
