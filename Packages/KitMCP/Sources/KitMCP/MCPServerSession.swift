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

    public init(
        transport: any Transport,
        stopProcess: (@Sendable () -> Void)? = nil,
        terminationStatus: (@Sendable () -> Int32?)? = nil
    ) {
        self.transport = transport
        self.stopProcess = stopProcess
        self.terminationStatus = terminationStatus
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
        process.executableURL = URL(fileURLWithPath: config.command)
        if !config.arguments.isEmpty {
            process.arguments = config.arguments
        }
        if !config.environment.isEmpty {
            var environment = ProcessInfo.processInfo.environment
            for (key, value) in config.environment {
                environment[key] = value
            }
            process.environment = environment
        }
        let inputPipe = Pipe()  // 客户端写请求 → 进程 stdin
        let outputPipe = Pipe() // 进程 stdout → 客户端读
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            throw MCPClientError.processSpawnFailed(
                "\(config.command): \(error.localizedDescription)"
            )
        }

        let box = ProcessBox(process)
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

        let client = Client(name: "Lumi", version: "1.0.0")
        do {
            try await client.connect(transport: prepared.transport)
        } catch {
            prepared.stopProcess?()
            self.prepared = nil
            throw MCPClientError.transport(error.localizedDescription)
        }
        self.client = client
        isConnected = true
    }

    public func disconnect() async {
        if let client {
            await client.disconnect()
        }
        client = nil
        prepared?.stopProcess?()
        prepared = nil
        isConnected = false
    }

    // MARK: - Tools

    public func listTools() async throws -> [MCPToolDescriptor] {
        let client = try connectedClient()
        let (tools, _) = try await client.listTools()
        return tools.map(MCPToolDescriptor.init(tool:))
    }

    public func callTool(
        name: String,
        arguments: [String: MCPJSONValue]
    ) async throws -> MCPCallResult {
        let client = try connectedClient()
        let mappedArguments = arguments.isEmpty
            ? nil
            : arguments.mapValues { $0.mcpValue() }
        let (content, isError) = try await client.callTool(
            name: name,
            arguments: mappedArguments
        )
        return MCPContentCodec.encode(content, isError: isError ?? false)
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
}
