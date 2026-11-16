import Foundation

/// 后端错误。
public enum ServerBackendError: Error, LocalizedError {
    case serverNotFound(String)
    case persistenceFailed(String)
    case invalidPID(Int)
    case invalidContainerName(String)
    case emptyCommand

    public var errorDescription: String? {
        switch self {
        case .serverNotFound(let key):
            return "No server matches '\(key)'."
        case .persistenceFailed(let reason):
            return "Failed to save server list: \(reason)"
        case .invalidPID(let pid):
            return "Invalid process ID: \(pid)."
        case .invalidContainerName(let name):
            return "Invalid container name: '\(name)'."
        case .emptyCommand:
            return "Command must not be empty."
        }
    }
}

/// 服务器配置存储 + SSH 探测的后端服务。
///
/// actor 隔离：UI（MainActor）与 Agent 工具（任意 executor）共享同一份
/// 配置与持久化文件，不需要额外加锁。
public actor ServerBackend {
    /// 远端命令执行器。默认走系统 SSH；测试可注入以构造延迟/失败场景。
    public typealias CommandRunner = @Sendable (ServerConfig, String) async throws -> String

    /// 固定的只读探测脚本：系统 / 负载 / 内存 / 磁盘。
    /// 不接受任何用户输入拼接，避免命令注入。
    public static let statusScript = """
    uname -sr; echo '---'; uptime; echo '---'; \
    (free -m 2>/dev/null || vm_stat 2>/dev/null); echo '---'; df -P / | tail -1
    """

    private let fileURL: URL
    private var configs: [ServerConfig]
    private let runner: CommandRunner

    public init(
        directory: URL,
        runner: @escaping CommandRunner = { try await SSHClient.run(config: $0, command: $1) }
    ) {
        self.runner = runner
        self.fileURL = directory.appendingPathComponent("servers.json", isDirectory: false)
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([ServerConfig].self, from: data) {
            self.configs = decoded
        } else {
            self.configs = []
        }
    }

    public func allServers() -> [ServerConfig] { configs }

    public func server(id: UUID) -> ServerConfig? {
        configs.first { $0.id == id }
    }

    /// 按名称（不区分大小写）或 UUID 字符串查找。
    public func server(matching key: String) -> ServerConfig? {
        if let id = UUID(uuidString: key), let found = server(id: id) {
            return found
        }
        let lowered = key.lowercased()
        return configs.first { $0.name.lowercased() == lowered }
    }

    public func add(_ config: ServerConfig) throws {
        configs.append(config)
        try persist()
    }

    public func remove(id: UUID) throws {
        configs.removeAll { $0.id == id }
        try persist()
    }

    /// 执行只读状态探测，返回原始输出文本。
    public func probe(id: UUID) async throws -> String {
        try await run(id: id, script: Self.statusScript)
    }

    /// 采集结构化指标（OS / 负载 / 内存 / 磁盘 / CPU）。
    public func metrics(id: UUID) async throws -> ServerMetrics {
        let output = try await run(id: id, script: RemoteScripts.metrics)
        return ServerMetricsParser.parseMetrics(output)
    }

    /// 按 CPU 降序的进程列表（最多 20 条）。
    public func processes(id: UUID) async throws -> [ServerProcess] {
        let output = try await run(id: id, script: RemoteScripts.processes)
        return ServerMetricsParser.parseProcesses(output)
    }

    /// 结束远端进程。pid 必须在合法范围内，否则抛错（不做钳制，
    /// 避免把非法输入变成对错误进程的操作）。
    public func killProcess(id: UUID, pid: Int, force: Bool) async throws {
        guard (1...4_194_304).contains(pid) else {
            throw ServerBackendError.invalidPID(pid)
        }
        _ = try await run(id: id, script: RemoteScripts.kill(pid: pid, force: force))
    }

    /// 容器列表（含已停止）。
    public func containers(id: UUID) async throws -> [ServerContainer] {
        let output = try await run(id: id, script: RemoteScripts.containers)
        return ServerMetricsParser.parseContainers(output)
    }

    /// 对容器执行 start / stop / restart。名称先做字符集校验。
    public func containerAction(id: UUID, name: String, action: ServerContainerAction) async throws {
        guard ServerContainer.isValidName(name) else {
            throw ServerBackendError.invalidContainerName(name)
        }
        _ = try await run(id: id, script: RemoteScripts.container(action: action, name: name))
    }

    /// 执行用户命令（控制台 / server_exec 工具）。
    /// 命令原样交给远端 shell —— 这是该功能的本意；
    /// 风险分级由 `ServerExecRisk` 在调用前完成。
    public func exec(id: UUID, command: String) async throws -> String {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ServerBackendError.emptyCommand }
        return try await run(id: id, script: trimmed)
    }

    private func run(id: UUID, script: String) async throws -> String {
        guard let config = server(id: id) else {
            throw ServerBackendError.serverNotFound(id.uuidString)
        }
        return try await runner(config, script)
    }

    private func persist() throws {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(configs)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw ServerBackendError.persistenceFailed(error.localizedDescription)
        }
    }
}