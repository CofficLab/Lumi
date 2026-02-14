
import Foundation
import MCP
import Combine
import OSLog
import SwiftUI
import MagicKit

@MainActor
class MCPService: ObservableObject, SuperLog {
    static let shared = MCPService()
    
    @Published var configs: [MCPServerConfig] = []
    @Published var connectedClients: [String: Client] = [:]
    @Published var tools: [AgentTool] = []
    @Published var connectionErrors: [String: String] = [:]
    
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
        
        // Remove client and update tools
        if connectedClients[name] != nil {
            connectedClients.removeValue(forKey: name)
            updateTools()
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
        
        // Use SubprocessTransport to spawn the MCP server
        let transport = SubprocessTransport(
            command: config.command,
            arguments: config.args,
            environment: config.env
        )
        
        do {
            // Clear previous error
            connectionErrors.removeValue(forKey: config.name)
            
            os_log("\(Self.t)Connecting to MCP server: \(config.name)")
            try await client.connect(transport: transport)
            connectedClients[config.name] = client
            os_log("\(Self.t)Connected to MCP server: \(config.name)")
            
            // List tools
            let (mcpTools, _) = try await client.listTools()
            os_log("\(Self.t)Found \(mcpTools.count) tools for \(config.name)")
            
            updateTools()
            
        } catch {
            let errorMsg = error.localizedDescription
            os_log(.error, "\(Self.t)Failed to connect to MCP server \(config.name): \(errorMsg)")
            connectionErrors[config.name] = errorMsg
        }
    }
    
    func updateTools() {
        Task {
            var newTools: [AgentTool] = []
            for (_, client) in connectedClients {
                if let (mcpTools, _) = try? await client.listTools() {
                    let adapters = mcpTools.map { MCPToolAdapter(client: client, tool: $0) }
                    newTools.append(contentsOf: adapters)
                }
            }
            // Use MainActor.run to update published property if needed, but we are already on MainActor
            self.tools = newTools
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
