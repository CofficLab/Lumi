
import Foundation
import MCP
import OSLog

/// Adapts an MCP Tool to the AgentTool protocol
final class MCPToolAdapter: AgentTool, @unchecked Sendable {
    let client: Client
    let mcpTool: MCP.Tool
    let serverName: String
    
    init(client: Client, tool: MCP.Tool, serverName: String) {
        self.client = client
        self.mcpTool = tool
        self.serverName = serverName
    }
    
    var name: String {
        // Follow claude-code convention: mcp__<server_name>__<tool_name>
        // Sanitize server name to be safe for tool names (only alphanumeric and underscores)
        let safeServerName = serverName.replacingOccurrences(of: "-", with: "_")
                                       .replacingOccurrences(of: " ", with: "_")
                                       .lowercased()
        return "mcp__\(safeServerName)__\(mcpTool.name)"
    }
    
    var description: String {
        mcpTool.description ?? ""
    }
    
    var inputSchema: [String: Any] {
        // Convert MCP.JSONSchema to [String: Any]
        guard let data = try? JSONEncoder().encode(mcpTool.inputSchema),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return json
    }
    
    func execute(arguments: [String: Any]) async throws -> String {
        os_log("[MCP] 🔧 开始执行 MCP 工具: \(self.name)")
        os_log("[MCP]   原始工具名: \(self.mcpTool.name)")

        // Convert arguments dictionary to MCP.Value
        let mcpArguments: [String: Value]
        do {
            let data = try JSONSerialization.data(withJSONObject: arguments)
            mcpArguments = try JSONDecoder().decode([String: Value].self, from: data)
            os_log("[MCP]   参数数量: \(mcpArguments.count)")
        } catch {
            os_log(.error, "[MCP] ❌ 参数转换失败: \(error.localizedDescription)")
            throw error
        }

        os_log("[MCP]   调用 client.callTool...")
        let startTime = Date()

        do {
            // 使用原始工具名而不是带前缀的名称
            let result = try await client.callTool(name: mcpTool.name, arguments: mcpArguments)
            let duration = Date().timeIntervalSince(startTime)

            os_log("[MCP] ✅ 工具调用成功 (耗时: \(String(format: "%.2f", duration))s)")

            if result.isError ?? false {
                let errorMessage = result.content.compactMap { content -> String? in
                    if case .text(let text) = content { return text }
                    return nil
                }.joined(separator: "\n")
                os_log(.error, "[MCP] ❌ 工具返回错误: \(errorMessage)")
                throw NSError(domain: "MCPToolAdapter", code: 1, userInfo: [NSLocalizedDescriptionKey: errorMessage.isEmpty ? "Unknown error from tool" : errorMessage])
            }

            // Combine content into string
            let output = result.content.compactMap { content -> String? in
                switch content {
                case .text(let text):
                    return text
                case .image(_, let mimeType, _):
                    return "[Image: \(mimeType)]"
                case .resource(let uri, _, _):
                    return "[Resource: \(uri)]"
                @unknown default:
                    return nil
                }
            }.joined(separator: "\n")

            os_log("[MCP] 📄 返回内容长度: \(output.count) 字符")
            return output
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            os_log(.error, "[MCP] ❌ 工具调用失败 (耗时: \(String(format: "%.2f", duration))s): \(error.localizedDescription)")
            throw error
        }
    }
}
