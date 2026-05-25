import Foundation
import AgentToolKit
import MCP
import MCPKit

/// Adapts an MCP Tool to the SuperAgentTool protocol.
final class MCPToolAdapter: SuperAgentTool, @unchecked Sendable, SuperLog {
    nonisolated static let emoji = "🔧"

    let client: Client
    let mcpTool: MCP.Tool
    let serverName: String

    init(discoveredTool: MCPDiscoveredTool) {
        self.client = discoveredTool.client
        self.mcpTool = discoveredTool.tool
        self.serverName = discoveredTool.serverName
    }

    var name: String {
        let safeServerName = serverName
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
            .lowercased()
        return "mcp__\(safeServerName)__\(mcpTool.name)"
    }

    /// MCP 工具的描述来自外部服务器，无法提供多语言版本。
    /// 两种语言均返回原始描述。
    func description(for language: LanguagePreference) -> String {
        mcpTool.description ?? ""
    }

    /// MCP 工具的 schema 来自外部服务器，无法提供多语言版本。
    /// 两种语言均返回原始 schema。
    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        guard let data = try? JSONEncoder().encode(mcpTool.inputSchema),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return [:]
        }
        return json
    }

    func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        try context.checkCancellation()
        return try await executeMCP(arguments: arguments, context: context)
    }

    private func executeMCP(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        if AgentMCPToolsPlugin.verbose {
            if AgentMCPToolsPlugin.verbose {
                            AgentMCPToolsPlugin.logger.info("\(self.t)[MCP] 开始执行 MCP 工具: \(self.name)")
            }
            if AgentMCPToolsPlugin.verbose {
                            AgentMCPToolsPlugin.logger.info("\(self.t)[MCP] 原始工具名: \(self.mcpTool.name)")
            }
        }

        let anyArguments: [String: Any] = arguments.mapValues { $0.value }

        let mcpArguments: [String: Value]
        do {
            let data = try JSONSerialization.data(withJSONObject: anyArguments)
            mcpArguments = try JSONDecoder().decode([String: Value].self, from: data)
            if AgentMCPToolsPlugin.verbose {
                if AgentMCPToolsPlugin.verbose {
                                    AgentMCPToolsPlugin.logger.info("\(self.t)[MCP] 参数数量: \(mcpArguments.count)")
                }
            }
        } catch {
            if AgentMCPToolsPlugin.verbose {
                            AgentMCPToolsPlugin.logger.error("\(self.t)[MCP] 参数转换失败: \(error.localizedDescription)")
            }
            throw error
        }

        if AgentMCPToolsPlugin.verbose {
            if AgentMCPToolsPlugin.verbose {
                            AgentMCPToolsPlugin.logger.info("\(self.t)[MCP] 调用 client.callTool...")
            }
        }
        let startTime = Date()

        do {
            try context.checkCancellation()
            let result = try await withTaskCancellationHandler {
                try await client.callTool(name: mcpTool.name, arguments: mcpArguments)
            } onCancel: {
                context.cancel()
            }
            try context.checkCancellation()
            let duration = Date().timeIntervalSince(startTime)

            if AgentMCPToolsPlugin.verbose {
                if AgentMCPToolsPlugin.verbose {
                                    AgentMCPToolsPlugin.logger.info("\(self.t)[MCP] 工具调用成功 (耗时: \(String(format: "%.2f", duration))s)")
                }
            }

            if result.isError ?? false {
                let errorMessage = result.content.compactMap { content -> String? in
                    if case .text(let text, _, _) = content { return text }
                    return nil
                }.joined(separator: "\n")
                if AgentMCPToolsPlugin.verbose {
                                    AgentMCPToolsPlugin.logger.error("\(self.t)[MCP] 工具返回错误: \(errorMessage)")
                }
                throw NSError(
                    domain: "MCPToolAdapter",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: errorMessage.isEmpty ? "Unknown error from tool" : errorMessage]
                )
            }

            var outputParts: [String] = []
            for content in result.content {
                switch content {
                case .text(let text, _, _):
                    outputParts.append(text)
                case .image(_, let mimeType, _, _):
                    outputParts.append("[Image: \(mimeType)]")
                case .resource(let uri, _, _):
                    outputParts.append("[Resource: \(uri)]")
                case .audio(_, let mimeType, _, _):
                    outputParts.append("[Audio: \(mimeType)]")
                @unknown default:
                    break
                }
            }
            let output = outputParts.joined(separator: "\n")

            if AgentMCPToolsPlugin.verbose {
                if AgentMCPToolsPlugin.verbose {
                                    AgentMCPToolsPlugin.logger.info("\(self.t)[MCP] 返回内容长度: \(output.count) 字符")
                }
            }
            return output
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            if AgentMCPToolsPlugin.verbose {
                            AgentMCPToolsPlugin.logger.error("\(self.t)[MCP] 工具调用失败 (耗时: \(String(format: "%.2f", duration))s): \(error.localizedDescription)")
            }
            throw error
        }
    }

    func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "MCP \(mcpTool.name)"
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .high
    }
}
