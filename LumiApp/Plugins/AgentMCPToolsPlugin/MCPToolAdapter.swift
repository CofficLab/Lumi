import Foundation
import MagicKit
import MCP

/// Adapts an MCP Tool to the AgentTool protocol.
final class MCPToolAdapter: AgentTool, @unchecked Sendable, SuperLog {
    nonisolated static let emoji = "🔧"

    let client: Client
    let mcpTool: MCP.Tool
    let serverName: String

    init(client: Client, tool: MCP.Tool, serverName: String) {
        self.client = client
        self.mcpTool = tool
        self.serverName = serverName
    }

    var name: String {
        let safeServerName = serverName
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
            .lowercased()
        return "mcp__\(safeServerName)__\(mcpTool.name)"
    }

    var description: String {
        mcpTool.description ?? ""
    }

    var inputSchema: [String: Any] {
        guard let data = try? JSONEncoder().encode(mcpTool.inputSchema),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return [:]
        }
        return json
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        AgentMCPToolsPlugin.logger.info("\(self.t)[MCP] 开始执行 MCP 工具: \(self.name)")
        AgentMCPToolsPlugin.logger.info("\(self.t)[MCP] 原始工具名: \(self.mcpTool.name)")

        let anyArguments: [String: Any] = arguments.mapValues { $0.value }

        let mcpArguments: [String: Value]
        do {
            let data = try JSONSerialization.data(withJSONObject: anyArguments)
            mcpArguments = try JSONDecoder().decode([String: Value].self, from: data)
            AgentMCPToolsPlugin.logger.info("\(self.t)[MCP] 参数数量: \(mcpArguments.count)")
        } catch {
            AgentMCPToolsPlugin.logger.error("\(self.t)[MCP] 参数转换失败: \(error.localizedDescription)")
            throw error
        }

        AgentMCPToolsPlugin.logger.info("\(self.t)[MCP] 调用 client.callTool...")
        let startTime = Date()

        do {
            let result = try await client.callTool(name: mcpTool.name, arguments: mcpArguments)
            let duration = Date().timeIntervalSince(startTime)

            AgentMCPToolsPlugin.logger.info("\(self.t)[MCP] 工具调用成功 (耗时: \(String(format: "%.2f", duration))s)")

            if result.isError ?? false {
                let errorMessage = result.content.compactMap { content -> String? in
                    if case .text(let text) = content { return text }
                    return nil
                }.joined(separator: "\n")
                AgentMCPToolsPlugin.logger.error("\(self.t)[MCP] 工具返回错误: \(errorMessage)")
                throw NSError(
                    domain: "MCPToolAdapter",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: errorMessage.isEmpty ? "Unknown error from tool" : errorMessage]
                )
            }

            var outputParts: [String] = []
            for content in result.content {
                switch content {
                case .text(let text):
                    outputParts.append(text)
                case .image(_, let mimeType, _):
                    outputParts.append("[Image: \(mimeType)]")
                case .resource(let uri, _, _):
                    outputParts.append("[Resource: \(uri)]")
                case .audio(_, let mimeType):
                    outputParts.append("[Audio: \(mimeType)]")
                @unknown default:
                    break
                }
            }
            let output = outputParts.joined(separator: "\n")

            AgentMCPToolsPlugin.logger.info("\(self.t)[MCP] 返回内容长度: \(output.count) 字符")
            return output
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            AgentMCPToolsPlugin.logger.error("\(self.t)[MCP] 工具调用失败 (耗时: \(String(format: "%.2f", duration))s): \(error.localizedDescription)")
            throw error
        }
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .high
    }
}

