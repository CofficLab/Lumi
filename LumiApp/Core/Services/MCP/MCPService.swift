import Foundation
import MCP
import Combine
import OSLog
import MagicKit

/// MCP 服务：负责管理 MCP 服务器连接和工具发现
///
/// 设计原则：
/// - 不在主线程上运行，所有操作都是异步的
/// - 通过 Combine Publishers 通知状态变化
/// - ViewModel 层负责将状态暴露给 UI
///
/// 注意：此类通过方法内部同步保证线程安全，因此可以安全地在并发代码中使用
class MCPService: SuperLog, @unchecked Sendable {
    nonisolated static let verbose = true
    nonisolated static let emoji = "🐘"

    // MARK: - Combine Publishers (状态变化通知)

    /// 配置列表变化通知
    let configsPublisher = PassthroughSubject<[MCPServerConfig], Never>()

    /// 工具列表变化通知
    let toolsPublisher = PassthroughSubject<[AgentTool], Never>()

    /// 连接错误变化通知
    let connectionErrorsPublisher = PassthroughSubject<[String: String], Never>()

    /// 连接客户端变化通知
    let connectedClientsPublisher = PassthroughSubject<[String: Client], Never>()

    // MARK: - 状态属性 (非 @Published)

    /// 所有 MCP 服务器配置
    private(set) var configs: [MCPServerConfig] = []

    /// 已连接的 MCP 客户端
    private(set) var connectedClients: [String: Client] = [:]

    /// 可用的工具列表
    private(set) var tools: [AgentTool] = []

    /// 连接错误信息
    private(set) var connectionErrors: [String: String] = [:]

    // 缓存已获取的工具列表，避免重复调用 listTools()
    private var cachedTools: [String: [MCP.Tool]] = [:]

    private let storageKey = "MCPService_Configs"
    private var cancellables = Set<AnyCancellable>()

    init() {
        // 同步加载配置（数据量小，不会阻塞）
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let savedConfigs = try? JSONDecoder().decode([MCPServerConfig].self, from: data) {
            self.configs = savedConfigs
        }

        // 延迟自动连接，确保应用已准备好
        Task.detached {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 秒
            await self.connectAll()
        }
    }

    // MARK: - 配置管理

    /// 从 UserDefaults 加载配置
    func loadConfigs() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let savedConfigs = try? JSONDecoder().decode([MCPServerConfig].self, from: data) {
            self.configs = savedConfigs
        } else {
            self.configs = []
        }
        configsPublisher.send(configs)
    }

    /// 保存配置到 UserDefaults
    func saveConfigs() {
        if let data = try? JSONEncoder().encode(configs) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    /// 添加服务器配置
    /// - Parameter config: MCP 服务器配置
    func addConfig(_ config: MCPServerConfig) {
        // 移除同名配置（如果存在）
        if let index = configs.firstIndex(where: { $0.name == config.name }) {
            configs.remove(at: index)
        }
        configs.append(config)
        saveConfigs()
        configsPublisher.send(configs)

        // 异步连接
        Task.detached {
            await self.connect(config: config)
        }
    }

    /// 移除服务器配置
    /// - Parameter name: 配置名称
    func removeConfig(name: String) {
        configs.removeAll { $0.name == name }
        saveConfigs()
        configsPublisher.send(configs)

        // 移除客户端和缓存
        if connectedClients[name] != nil {
            connectedClients.removeValue(forKey: name)
            cachedTools.removeValue(forKey: name)
            connectedClientsPublisher.send(connectedClients)

            // 更新工具列表
            Task.detached {
                await self.updateToolsFromCache()
            }
        }
    }

    // MARK: - 连接管理

    /// 连接所有已配置的服务器
    func connectAll() async {
        let configsToConnect = configs.filter { !$0.disabled }
        for config in configsToConnect {
            await connect(config: config)
        }
    }

    /// 连接单个服务器
    /// - Parameter config: MCP 服务器配置
    func connect(config: MCPServerConfig) async {
        guard !config.disabled else { return }

        let client = Client(name: "Lumi-\(config.name)", version: "1.0.0")

        let transport: Transport

        // 根据配置选择传输方式
        switch config.transportType ?? .stdio {
        case .sse:
            guard let urlString = config.url, let url = URL(string: urlString) else {
                let errorMsg = "Invalid URL for SSE transport"
                connectionErrors[config.name] = errorMsg
                connectionErrorsPublisher.send(connectionErrors)
                os_log(.error, "\(Self.t)\(errorMsg)")
                return
            }

            // 准备请求头
            var headers: [String: String] = [:]
            // 自动将 Z_AI_API_KEY 映射到 Authorization header (智谱 MCP)
            if let apiKey = config.env["Z_AI_API_KEY"], !apiKey.isEmpty {
                headers["Authorization"] = "Bearer \(apiKey)"
            }

            transport = SSEClientTransport(url: url, headers: headers)

        case .stdio:
            // 使用子进程运行 MCP 服务器
            transport = SubprocessTransport(
                command: config.command,
                arguments: config.args,
                environment: config.env
            )
        }

        do {
            // 清除之前的错误
            connectionErrors.removeValue(forKey: config.name)
            connectionErrorsPublisher.send(connectionErrors)

            if Self.verbose {
                os_log("\(Self.t)Connecting to MCP server: \(config.name)")
            }
            try await client.connect(transport: transport)
            connectedClients[config.name] = client
            connectedClientsPublisher.send(connectedClients)

            if Self.verbose {
                os_log("\(Self.t)Connected to MCP server: \(config.name)")
            }

            // 获取工具列表并缓存
            let (mcpTools, _) = try await client.listTools()
            cachedTools[config.name] = mcpTools

            if Self.verbose {
                os_log("\(Self.t)Found \(mcpTools.count) tools for \(config.name)")
                for tool in mcpTools {
                    os_log("\(Self.t)  - \(tool.name): \(tool.description ?? "无描述")")
                }
            }

            // 更新工具列表
            await updateToolsFromCache()

        } catch {
            let errorMsg = error.localizedDescription
            os_log(.error, "\(Self.t)Failed to connect to MCP server \(config.name): \(errorMsg)")
            connectionErrors[config.name] = errorMsg
            connectionErrorsPublisher.send(connectionErrors)
        }
    }

    // MARK: - 工具管理

    /// 更新工具列表（从服务器获取）
    func updateTools() async {
        if Self.verbose {
            os_log("\(Self.t)🔄 开始更新工具列表，当前已连接服务器：\(self.connectedClients.count) 个")
        }

        var newTools: [AgentTool] = []

        for (serverName, client) in connectedClients {
            if Self.verbose {
                os_log("\(Self.t)  正在获取 \(serverName) 的工具列表...")
            }
            do {
                let (mcpTools, _) = try await client.listTools()
                if Self.verbose {
                    os_log("\(Self.t)  \(serverName) 返回 \(mcpTools.count) 个工具")
                }

                let adapters = mcpTools.map { MCPToolAdapter(client: client, tool: $0, serverName: serverName) }
                newTools.append(contentsOf: adapters)
                if Self.verbose {
                    os_log("\(Self.t)  成功添加 \(adapters.count) 个适配器")
                }
            } catch {
                os_log(.error, "\(Self.t)  获取 \(serverName) 工具失败：\(error.localizedDescription)")
            }
        }

        self.tools = newTools
        toolsPublisher.send(tools)

        if Self.verbose {
            os_log("\(Self.t)✅ 工具列表已更新：\(newTools.count) 个 MCP 工具")
            for tool in newTools {
                os_log("\(Self.t)  - \(tool.name)")
            }
        }
    }

    /// 从缓存更新工具列表（避免重复调用 listTools）
    func updateToolsFromCache() async {
        if Self.verbose {
            os_log("\(Self.t)🔄 从缓存更新工具列表，已缓存服务器：\(self.cachedTools.count) 个")
        }

        var newTools: [AgentTool] = []

        for (serverName, mcpTools) in cachedTools {
            guard let client = connectedClients[serverName] else {
                os_log(.error, "\(Self.t)  警告：服务器 \(serverName) 有缓存但无客户端连接")
                continue
            }

            let adapters = mcpTools.map { MCPToolAdapter(client: client, tool: $0, serverName: serverName) }
            newTools.append(contentsOf: adapters)
        }

        self.tools = newTools
        toolsPublisher.send(tools)

        if Self.verbose {
            os_log("\(Self.t)✅ 工具列表已更新（从缓存）: 共 \(newTools.count) 个 MCP 工具")
            for tool in newTools {
                os_log("\(Self.t)  - \(tool.name)")
            }
        }
    }

    // MARK: - Helper Methods

    /// 安装 Vision MCP
    /// - Parameter apiKey: API 密钥
    func installVisionMCP(apiKey: String) {
        let config = MCPServerConfig(
            name: "Vision MCP",
            command: "npx",
            args: ["-y", "@z_ai/mcp-server"],
            env: ["Z_AI_API_KEY": apiKey],
            homepage: "https://docs.bigmodel.cn/cn/coding-plan/mcp/vision-mcp-server"
        )
        addConfig(config)
    }

    /// 获取状态报告（用于调试）
    /// - Returns: 状态报告字符串
    func getStatusReport() -> String {
        var report = "**MCP Status**\n\n"

        if configs.isEmpty {
            report += "No MCP servers configured.\n"
        } else {
            for config in configs {
                let isConnected = connectedClients[config.name] != nil
                let status = isConnected ? "✅ Connected" : "❌ Disconnected"
                report += "- **\(config.name)**: \(status)\n"

                if !isConnected, let error = connectionErrors[config.name] {
                    report += "  - Error: \(error)\n"
                }
            }
        }

        report += "\n**Available Tools (\(tools.count))**:\n"
        for tool in tools {
            report += "- `\(tool.name)`: \(tool.description)\n"
        }

        return report
    }
}
