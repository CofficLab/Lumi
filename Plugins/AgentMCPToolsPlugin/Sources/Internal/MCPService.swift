import Combine
import SuperLogKit
import Foundation
import Logging
import MCP

public final class MCPService: SuperLog, @unchecked Sendable {
    public let toolsPublisher = PassthroughSubject<[MCPDiscoveredTool], Never>()

    public private(set) var configs: [MCPServerConfig]
    public private(set) var connectedClients: [String: Client] = [:]
    public private(set) var tools: [MCPDiscoveredTool] = []

    private var cachedTools: [String: [MCP.Tool]] = [:]
    private let logger: Logging.Logger

    public init(configs: [MCPServerConfig] = [], logger: Logging.Logger? = nil) {
        self.configs = configs
        self.logger = logger ?? Logging.Logger(label: "Lumi.MCPKit.MCPService")
    }

    public func updateConfigs(_ configs: [MCPServerConfig]) {
        self.configs = configs
    }

    public func connectAll() async {
        let configsToConnect = configs.filter { !$0.disabled }
        for config in configsToConnect {
            await connect(config: config)
        }
    }

    public func connect(config: MCPServerConfig) async {
        guard !config.disabled else { return }

        let client = Client(name: "Lumi-\(config.name)", version: "1.0.0")

        let transport: Transport
        switch config.transportType ?? .stdio {
        case .sse:
            guard let urlString = config.url, let url = URL(string: urlString) else {
                logger.error("\(Self.t)Invalid MCP SSE URL for server \(config.name)")
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
            try await client.connect(transport: transport)
            connectedClients[config.name] = client

            let (mcpTools, _) = try await client.listTools()
            cachedTools[config.name] = mcpTools

            await updateToolsFromCache()
        } catch {
            logger.error("\(Self.t)Failed to connect to MCP server \(config.name): \(error.localizedDescription)")
        }
    }

    public func disconnectAll() async {
        let clients = connectedClients.values

        connectedClients.removeAll()
        cachedTools.removeAll()
        tools.removeAll()
        toolsPublisher.send([])

        for client in clients {
            await client.disconnect()
        }
    }

    public func updateToolsFromCache() async {
        var newTools: [MCPDiscoveredTool] = []

        for (serverName, mcpTools) in cachedTools {
            guard let client = connectedClients[serverName] else { continue }
            let tools = mcpTools.map { MCPDiscoveredTool(serverName: serverName, client: client, tool: $0) }
            newTools.append(contentsOf: tools)
        }

        tools = newTools
        toolsPublisher.send(tools)
    }
}
