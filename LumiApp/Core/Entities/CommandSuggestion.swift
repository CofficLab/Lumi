import Foundation

struct CommandSuggestion: Identifiable, Equatable {
    let id = UUID()
    let command: String
    let description: String
    let category: String

    /// 静态命令列表
    static let staticCommands: [CommandSuggestion] = [
        CommandSuggestion(command: "/clear", description: "Clear chat history", category: "System"),
        CommandSuggestion(command: "/help", description: "Show all available commands", category: "System"),
        CommandSuggestion(command: "/plan", description: "Generate implementation plan", category: "Productivity"),
        CommandSuggestion(command: "/mcp list", description: "List connected MCP servers", category: "MCP"),
        CommandSuggestion(command: "/mcp install vision", description: "Install Vision MCP Server", category: "MCP"),
        CommandSuggestion(command: "/commands", description: "List all available commands", category: "System"),
    ]
}
