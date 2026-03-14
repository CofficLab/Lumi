import Foundation
import MCP
import Combine
import OSLog
import MagicKit

/// MCP 服务：负责管理 MCP 服务器连接和工具发现（插件内部实现细节）。
final class MCPService: SuperLog, @unchecked Sendable {
    nonisolated static let verbose = true
    nonisolated static let emoji = "🐘"

    // MARK: - Combine Publishers

    let toolsPublisher = PassthroughSubject<[AgentTool], Never>()

    // MARK: - State

    private(set) var configs: [MCPServerConfig] = []
    private(set) var connectedClients: [String: Client] = [:]
    private(set) var tools: [AgentTool] = []

    private var cachedTools: [String: [MCP.Tool]] = [:]

    private let storageKey = "MCPService_Configs"

    init() {
        if let data = AppSettingsStore.shared.data(forKey: storageKey),
           let savedConfigs = try? JSONDecoder().decode([MCPServerConfig].self, from: data)
        {
            self.configs = savedConfigs
        }
    }

    // MARK: - Connection

    func connectAll() async {
        let configsToConnect = configs.filter { !$0.disabled }
        for config in configsToConnect {
            await connect(config: config)
        }
    }

    func connect(config: MCPServerConfig) async {
        guard !config.disabled else { return }

        let client = Client(name: "Lumi-\(config.name)", version: "1.0.0")

        let transport: Transport
        switch config.transportType ?? .stdio {
        case .sse:
            guard let urlString = config.url, let url = URL(string: urlString) else {
                if Self.verbose { os_log(.error, "\(Self.t)Invalid URL for SSE transport") }
                return
            }

            var headers: [String: String] = [:]
            if let apiKey = config.env["Z_AI_API_KEY"], !apiKey.isEmpty {
                headers["Authorization"] = "Bearer \(apiKey)"
            }

            transport = SSEClientTransport(url: url, headers: headers)

        case .stdio:
            transport = SubprocessTransport(
                command: config.command,
                arguments: config.args,
                environment: config.env
            )
        }

        do {
            if Self.verbose { os_log("\(Self.t)Connecting to MCP server: \(config.name)") }
            try await client.connect(transport: transport)
            connectedClients[config.name] = client

            let (mcpTools, _) = try await client.listTools()
            cachedTools[config.name] = mcpTools

            await updateToolsFromCache()
        } catch {
            if Self.verbose {
                os_log(.error, "\(Self.t)Failed to connect to MCP server \(config.name): \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Tools

    func updateToolsFromCache() async {
        var newTools: [AgentTool] = []

        for (serverName, mcpTools) in cachedTools {
            guard let client = connectedClients[serverName] else { continue }
            let adapters = mcpTools.map { MCPToolAdapter(client: client, tool: $0, serverName: serverName) }
            newTools.append(contentsOf: adapters)
        }

        tools = newTools
        toolsPublisher.send(tools)

        if Self.verbose {
            os_log("\(Self.t)✅ MCP tools updated: \(newTools.count)")
        }
    }
}

