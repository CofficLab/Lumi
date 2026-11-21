import Foundation
import MCP
import System

/// 传输准备结果：会话持有一个 transport，以及可选的进程清理/退出状态查询。
public struct MCPPreparedTransport: Sendable {
    /// 实际使用的 MCP transport。
    public let transport: any Transport
    /// stdio 场景终止子进程；HTTP 场景为 `nil`。
    public let stopProcess: (@Sendable () -> Void)?
    /// 查询子进程是否已退出及其退出码；仍在运行返回 `nil`。
    public let terminationStatus: (@Sendable () -> Int32?)?
    /// stdio 子进程退出码流：主动 terminate 与意外退出都会发出（至多一次）；
    /// 「是否意外」由会话层结合主动断开标记判定（#473）。HTTP 场景为 `nil`。
    public let processExit: AsyncStream<Int32>?
    /// stdio 场景由子进程输出的诊断信息；HTTP 场景为 `nil`。
    public let diagnosticOutput: (@Sendable () -> String?)?
    /// 释放本次传输占用的管道 fd（stdio 场景）；HTTP 场景为 `nil`。
    ///
    /// `Foundation.Pipe` 持有的 fd 不能只依赖 ARC/autorelease pool：反复
    /// connect/disconnect 时会持续堆积，最终耗尽进程 fd 上限（EMFILE）。
    public let cleanup: (@Sendable () -> Void)?

    public init(
        transport: any Transport,
        stopProcess: (@Sendable () -> Void)? = nil,
        terminationStatus: (@Sendable () -> Int32?)? = nil,
        processExit: AsyncStream<Int32>? = nil,
        diagnosticOutput: (@Sendable () -> String?)? = nil,
        cleanup: (@Sendable () -> Void)? = nil
    ) {
        self.transport = transport
        self.stopProcess = stopProcess
        self.terminationStatus = terminationStatus
        self.processExit = processExit
        self.diagnosticOutput = diagnosticOutput
        self.cleanup = cleanup
    }
}

/// 收集 MCP 子进程 stderr，避免启动失败时丢失最有用的诊断信息。
private final class ProcessDiagnosticBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()
    private let limit = 64 * 1024

    func append(_ chunk: Data) {
        lock.lock()
        defer { lock.unlock() }
        let remaining = limit - data.count
        guard remaining > 0 else { return }
        data.append(chunk.prefix(remaining))
    }

    func contents() -> String? {
        lock.lock()
        defer { lock.unlock() }
        guard !data.isEmpty else { return nil }
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// 进程相关的 `@unchecked Sendable` 包装：`Process` 本身非 Sendable，
/// 但仅在本包内串行使用（启动后只读 + 终止）。
private final class ProcessBox: @unchecked Sendable {
    let process: Process
    init(_ process: Process) {
        self.process = process
    }
}

/// 默认传输准备：stdio 时 spawn 子进程并接管道，streamableHTTP 时连远端。
public enum MCPProcessTransport {
    public static func prepare(config: MCPServerConfig) throws -> MCPPreparedTransport {
        switch config.transport {
        case .stdio:
            return try prepareStdio(config: config)
        case .streamableHTTP:
            return try prepareHTTP(config: config)
        }
    }

    private static func prepareStdio(config: MCPServerConfig) throws -> MCPPreparedTransport {
        let process = Process()
        // 经 /usr/bin/env 启动：`command` 可为 PATH 中的命令名（xcrun / npx / uvx…），
        // 也保留绝对路径用法（env 会直接透传）。
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [config.command] + config.arguments
        if !config.environment.isEmpty {
            var environment = ProcessInfo.processInfo.environment
            for (key, value) in config.environment {
                environment[key] = value
            }
            process.environment = environment
        }
        let inputPipe = Pipe()  // 客户端写请求 → 进程 stdin
        let outputPipe = Pipe() // 进程 stdout → 客户端读
        let errorPipe = Pipe()
        let diagnosticBuffer = ProcessDiagnosticBuffer()
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if chunk.isEmpty {
                handle.readabilityHandler = nil
            } else {
                diagnosticBuffer.append(chunk)
            }
        }

        let box = ProcessBox(process)
        let (exitStream, exitContinuation) = AsyncStream.makeStream(of: Int32.self)
        // 退出观测必须由 terminationHandler 主动上报（#473）：只靠下一次
        // 操作时的被动查询，意外退出后状态与已注册工具会一直保持过期值。
        process.terminationHandler = { _ in
            exitContinuation.yield(box.process.terminationStatus)
            exitContinuation.finish()
        }

        do {
            try process.run()
        } catch {
            throw MCPClientError.processSpawnFailed(
                "\(config.command): \(error.localizedDescription)"
            )
        }

        let transport = StdioTransport(
            input: FileDescriptor(rawValue: outputPipe.fileHandleForReading.fileDescriptor),
            output: FileDescriptor(rawValue: inputPipe.fileHandleForWriting.fileDescriptor)
        )
        return MCPPreparedTransport(
            transport: transport,
            stopProcess: { [box] in
                if box.process.isRunning {
                    box.process.terminate()
                }
            },
            terminationStatus: { [box] in
                box.process.isRunning ? nil : box.process.terminationStatus
            },
            processExit: exitStream,
            diagnosticOutput: { diagnosticBuffer.contents() },
            cleanup: { [errorPipe, inputPipe, outputPipe] in
                errorPipe.fileHandleForReading.readabilityHandler = nil
                try? errorPipe.fileHandleForReading.close()
                try? errorPipe.fileHandleForWriting.close()
                try? outputPipe.fileHandleForReading.close()
                try? outputPipe.fileHandleForWriting.close()
                try? inputPipe.fileHandleForReading.close()
                try? inputPipe.fileHandleForWriting.close()
            }
        )
    }

    private static func prepareHTTP(config: MCPServerConfig) throws -> MCPPreparedTransport {
        guard let urlString = config.url, let url = URL(string: urlString) else {
            throw MCPClientError.invalidConfiguration(
                "streamableHTTP requires a non-empty url"
            )
        }
        return MCPPreparedTransport(
            transport: HTTPClientTransport(endpoint: url, streaming: true)
        )
    }
}

/// MCP 客户端会话默认实现。
///
/// - stdio：spawn 服务器子进程，经 stdin/stdout 交换 JSON-RPC；
/// - streamableHTTP：连接远端端点。
/// - 测试可注入自定义 `prepare`（如 `InMemoryTransport`），不依赖真实进程。
public actor MCPServerSession: MCPServerServing {
    public let config: MCPServerConfig
    public private(set) var isConnected = false
    /// 服务器子进程最近的退出码（若发生过退出）。
    public private(set) var lastTerminationStatus: Int32?

    private let prepare: (MCPServerConfig) throws -> MCPPreparedTransport
    private var prepared: MCPPreparedTransport?
    private var client: Client?
    /// 子进程退出监测任务（仅 stdio 且连接成功后存在）。
    private var exitMonitor: Task<Void, Never>?
    /// 意外退出事件流及其续体；主动 `disconnect()` 不产生事件（#473）。
    private var unexpectedExitStream: AsyncStream<Int32>?
    private var unexpectedExitContinuation: AsyncStream<Int32>.Continuation?
    /// `disconnect()` 置位：随后的子进程退出视为主动停止，不算意外退出（#473）。
    private var stoppingIntentionally = false
    /// 连接代次（#401）：每次 `disconnect()` 递增。`connect()` 的 await
    /// 期间被 disconnect 后，迟到的完成不得写回局部 client。
    private var connectionGeneration = 0

    public init(
        config: MCPServerConfig,
        prepare: ((MCPServerConfig) throws -> MCPPreparedTransport)? = nil
    ) {
        self.config = config
        self.prepare = prepare ?? MCPProcessTransport.prepare
    }

    // MARK: - Connection

    public func connect() async throws {
        guard !isConnected else { return }

        let prepared: MCPPreparedTransport
        do {
            prepared = try prepare(config)
        } catch {
            throw error
        }
        self.prepared = prepared
        // 新连接生命周期开始：复位主动停止标记，否则重连后的意外退出
        // 会被上一次 disconnect 置位的标记吞掉，不触发撤回（#473）。
        stoppingIntentionally = false

        let generation = connectionGeneration
        let client = Client(name: "Lumi", version: "1.0.0")
        do {
            try await client.connect(transport: prepared.transport)
        } catch {
            prepared.stopProcess?()
            // 连接失败也要释放本次已创建的管道 fd。
            prepared.cleanup?()
            self.prepared = nil
            throw MCPClientError.transport(Self.message(error, diagnostics: prepared.diagnosticOutput?()))
        }
        // 连接建立期间被 disconnect（#401）：actor 重入使 disconnect 摸不到
        // 这个局部 client，迟到的完成既不写回也不生效；关闭后按未连接报错，
        // 状态归属由上层连接代次决定。
        guard connectionGeneration == generation else {
            await client.disconnect()
            throw MCPClientError.notConnected
        }
        self.client = client
        isConnected = true
        armUnexpectedExitMonitoring()
    }

    public func disconnect() async {
        connectionGeneration &+= 1
        // 先置主动停止标记：terminate 触发的退出经监测任务回到本 actor 时
        // 必须被吞掉，不得作为意外退出上报（#473）。
        stoppingIntentionally = true
        if let client {
            await client.disconnect()
        }
        client = nil
        prepared?.stopProcess?()
        // 释放 stdio 管道 fd，避免反复 connect/disconnect 造成 fd 泄漏。
        prepared?.cleanup?()
        prepared = nil
        isConnected = false
        exitMonitor?.cancel()
        exitMonitor = nil
        unexpectedExitContinuation?.finish()
        unexpectedExitContinuation = nil
        unexpectedExitStream = nil
    }

    /// 订阅子进程「意外退出」事件：未主动断开时子进程退出，发出退出码。
    ///
    /// 每个连接生命周期至多发出一次，随后流结束。不支持退出监测的实现
    /// （HTTP 传输、测试替身）由协议默认实现返回 `nil`。
    public func unexpectedTerminationEvents() async -> AsyncStream<Int32>? {
        unexpectedExitStream
    }

    // MARK: - Unexpected exit monitoring (#473)

    /// 连接成功后监测 stdio 子进程退出；非主动断开的退出经事件流上报。
    private func armUnexpectedExitMonitoring() {
        guard let processExit = prepared?.processExit, unexpectedExitStream == nil else { return }
        let (stream, continuation) = AsyncStream.makeStream(of: Int32.self)
        unexpectedExitStream = stream
        unexpectedExitContinuation = continuation
        exitMonitor = Task { [weak self] in
            for await code in processExit {
                guard let self else { break }
                await self.forwardExit(code)
            }
        }
    }

    private func forwardExit(_ code: Int32) {
        guard !stoppingIntentionally else { return }
        isConnected = false
        lastTerminationStatus = code
        unexpectedExitContinuation?.yield(code)
        unexpectedExitContinuation?.finish()
    }

    // MARK: - Tools

    public func listTools() async throws -> [MCPToolDescriptor] {
        let client = try connectedClient()
        do {
            // 工具列表可能分页：必须跟随 nextCursor 逐页取尽，否则第二页起的工具
            // 会被静默漏注册（#181）。跨页重名按名字去重，保留首次出现的描述。
            var descriptors: [MCPToolDescriptor] = []
            var seenNames: Set<String> = []
            var seenCursors: Set<String> = []
            var cursor: String?
            repeat {
                let (tools, nextCursor) = try await client.listTools(cursor: cursor)
                for tool in tools where seenNames.insert(tool.name).inserted {
                    descriptors.append(MCPToolDescriptor(tool: tool))
                }
                guard let nextCursor else { break }
                // 外部服务器可能错误地回吐重复游标；不设防会无限翻页挂起工具发现。
                guard seenCursors.insert(nextCursor).inserted else { break }
                cursor = nextCursor
            } while true
            return descriptors
        } catch {
            throw MCPClientError.transport(Self.message(error, diagnostics: prepared?.diagnosticOutput?()))
        }
    }

    public func callTool(
        name: String,
        arguments: [String: MCPJSONValue]
    ) async throws -> MCPCallResult {
        try Task.checkCancellation()
        let client = try connectedClient()
        let mappedArguments = arguments.isEmpty
            ? nil
            : arguments.mapValues { $0.mcpValue() }
        // 便利重载只回 (content, isError)，会丢掉 structuredContent；改用完整结果
        // 重载读取该字段，避免仅返回结构化内容的成功结果被落成空文本（#180）。
        let context: RequestContext<CallTool.Result> = try await client.callTool(
            name: name,
            arguments: mappedArguments
        )
        // 取消必须终止底层请求：cancelRequest 先以 CancellationError 释放本地
        // pending continuation，再尽力向服务器发送协议取消通知。服务器永不响应
        // 时本地等待也能立即结束，Job 不会永远停在 cancelling（#178）。
        let result = try await withTaskCancellationHandler {
            try await context.value
        } onCancel: {
            Task {
                try? await client.cancelRequest(
                    context.requestID,
                    reason: "Tool call cancelled by client"
                )
            }
        }
        return MCPContentCodec.encode(
            result.content,
            structuredContent: result.structuredContent,
            isError: result.isError ?? false
        )
    }

    // MARK: - Private

    private func connectedClient() throws -> Client {
        guard isConnected, let client else {
            throw MCPClientError.notConnected
        }
        if let status = prepared?.terminationStatus?() {
            lastTerminationStatus = status
            isConnected = false
            throw MCPClientError.serverTerminated(status)
        }
        return client
    }

    private static func message(_ error: Error, diagnostics: String?) -> String {
        guard let diagnostics, !diagnostics.isEmpty else { return error.localizedDescription }
        return "\(error.localizedDescription)\n\nstderr:\n\(diagnostics)"
    }
}
