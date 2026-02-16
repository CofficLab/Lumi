
import Foundation
import MCP
import Combine
import OSLog
import SwiftUI
import MagicKit

@MainActor
class MCPService: ObservableObject, SuperLog {
    nonisolated static let verbose = true
    
    static let shared = MCPService()
    
    @Published var configs: [MCPServerConfig] = []
    @Published var connectedClients: [String: Client] = [:]
    @Published var tools: [AgentTool] = []
    @Published var connectionErrors: [String: String] = [:]

    // 缓存已获取的工具列表，避免重复调用 listTools()
    private var cachedTools: [String: [MCP.Tool]] = [:]

    private let storageKey = "MCPService_Configs"
    
    private init() {
        loadConfigs()
        
        // Auto-connect after a short delay to ensure app is ready
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            await connectAll()
        }
    }
    
    func loadConfigs() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let savedConfigs = try? JSONDecoder().decode([MCPServerConfig].self, from: data) {
            self.configs = savedConfigs
        } else {
            self.configs = []
        }
    }
    
    func saveConfigs() {
        if let data = try? JSONEncoder().encode(configs) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    func addConfig(_ config: MCPServerConfig) {
        // Remove existing config with same name if any
        if let index = configs.firstIndex(where: { $0.name == config.name }) {
            configs.remove(at: index)
        }
        configs.append(config)
        saveConfigs()
        
        Task {
            await connect(config: config)
        }
    }
    
    func removeConfig(name: String) {
        configs.removeAll { $0.name == name }
        saveConfigs()

        // Remove client, cache and update tools
        if connectedClients[name] != nil {
            connectedClients.removeValue(forKey: name)
            cachedTools.removeValue(forKey: name)  // 清理缓存
            Task {
                await updateToolsFromCache()
            }
        }
    }
    
    func connectAll() async {
        for config in configs where !config.disabled {
            await connect(config: config)
        }
    }
    
    func connect(config: MCPServerConfig) async {
        guard !config.disabled else { return }
        
        let client = Client(name: "Lumi-\(config.name)", version: "1.0.0")
        
        let transport: Transport
        
        // Determine transport type. Default to stdio if not specified (backward compatibility)
        switch config.transportType ?? .stdio {
        case .sse:
            guard let urlString = config.url, let url = URL(string: urlString) else {
                let errorMsg = "Invalid URL for SSE transport"
                connectionErrors[config.name] = errorMsg
                os_log(.error, "\(Self.t)\(errorMsg)")
                return
            }
            
            // Prepare headers
            var headers: [String: String] = [:]
            // Automatically map Z_AI_API_KEY to Authorization header for Zhipu MCPs
            if let apiKey = config.env["Z_AI_API_KEY"], !apiKey.isEmpty {
                headers["Authorization"] = "Bearer \(apiKey)"
            }
            
            transport = SSEClientTransport(url: url, headers: headers)
            
        case .stdio:
            // Use SubprocessTransport to spawn the MCP server
            transport = SubprocessTransport(
                command: config.command,
                arguments: config.args,
                environment: config.env
            )
        }
        
        do {
            // Clear previous error
            connectionErrors.removeValue(forKey: config.name)
            
            os_log("\(Self.t)Connecting to MCP server: \(config.name)")
            try await client.connect(transport: transport)
            connectedClients[config.name] = client
            os_log("\(Self.t)Connected to MCP server: \(config.name)")

            // List tools and cache them
            let (mcpTools, _) = try await client.listTools()
            cachedTools[config.name] = mcpTools  // 缓存工具列表
            os_log("\(Self.t)Found \(mcpTools.count) tools for \(config.name)")
            if Self.verbose {
                for tool in mcpTools {
                    os_log("\(Self.t)  - \(tool.name): \(tool.description ?? "无描述")")
                }
            }

            // 立即更新工具列表（使用缓存，不重复调用 listTools）
            await updateToolsFromCache()
            
        } catch {
            let errorMsg = error.localizedDescription
            os_log(.error, "\(Self.t)Failed to connect to MCP server \(config.name): \(errorMsg)")
            connectionErrors[config.name] = errorMsg
        }
    }
    
    func updateTools() async {
        os_log("\(Self.t)🔄 开始更新工具列表，当前已连接服务器: \(self.connectedClients.count) 个")

        var newTools: [AgentTool] = []

        for (serverName, client) in connectedClients {
            os_log("\(Self.t)  正在获取 \(serverName) 的工具列表...")
            do {
                let (mcpTools, _) = try await client.listTools()
                os_log("\(Self.t)  \(serverName) 返回 \(mcpTools.count) 个工具")

                let adapters = mcpTools.map { MCPToolAdapter(client: client, tool: $0, serverName: serverName) }
                newTools.append(contentsOf: adapters)
                os_log("\(Self.t)  成功添加 \(adapters.count) 个适配器")
            } catch {
                os_log(.error, "\(Self.t)  获取 \(serverName) 工具失败: \(error.localizedDescription)")
            }
        }

        // 更新 published property（已在 MainActor 上）
        self.tools = newTools
        os_log("\(Self.t)✅ 工具列表已更新: \(newTools.count) 个 MCP 工具")

        if Self.verbose {
            for tool in newTools {
                os_log("\(Self.t)  - \(tool.name)")
            }
        }
    }

    /// 从缓存更新工具列表（避免重复调用 listTools）
    func updateToolsFromCache() async {
        os_log("\(Self.t)🔄 从缓存更新工具列表，已缓存服务器: \(self.cachedTools.count) 个")

        var newTools: [AgentTool] = []

        for (serverName, mcpTools) in cachedTools {
            guard let client = connectedClients[serverName] else {
                os_log(.error, "\(Self.t)  警告: 服务器 \(serverName) 有缓存但无客户端连接")
                continue
            }

            let adapters = mcpTools.map { MCPToolAdapter(client: client, tool: $0, serverName: serverName) }
            newTools.append(contentsOf: adapters)
        }

        // 更新 published property
        self.tools = newTools
        os_log("\(Self.t)✅ 工具列表已更新（从缓存）: 共 \(newTools.count) 个 MCP 工具")

        if Self.verbose {
            for tool in newTools {
                os_log("\(Self.t)  - \(tool.name)")
            }
        }
    }
    
    // MARK: - Helper to add Vision MCP
    
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
