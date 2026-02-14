import Foundation

enum SlashCommandResult {
    case handled
    case notHandled
    case error(String)
}

actor SlashCommandService {
    static let shared = SlashCommandService()
    
    func handle(input: String, viewModel: DevAssistantViewModel) async -> SlashCommandResult {
        guard input.hasPrefix("/") else { return .notHandled }
        
        let components = input.dropFirst().split(separator: " ", maxSplits: 1).map(String.init)
        guard let command = components.first else { return .notHandled }
        let arguments = components.count > 1 ? components[1] : ""
        
        switch command {
        case "clear":
            await viewModel.clearHistory()
            return .handled
            
        case "help":
            await viewModel.appendSystemMessage("""
            **Available Commands:**
            - `/clear`: Clear chat history and reset context.
            - `/plan [task]`: Generate a detailed implementation plan for a task.
            - `/help`: Show this help message.
            """)
            return .handled
            
        case "plan":
            if arguments.isEmpty {
                return .error("Usage: /plan [task description]")
            }
            // Trigger planning mode
            // We can implement this by sending a specific prompt to the LLM
            await viewModel.triggerPlanningMode(task: arguments)
            return .handled
            
        case "mcp":
            return await handleMCPCommand(args: arguments, viewModel: viewModel)
            
        default:
            return .error("Unknown command: /\(command)")
        }
    }
    
    private func handleMCPCommand(args: String, viewModel: DevAssistantViewModel) async -> SlashCommandResult {
        let components = args.split(separator: " ", maxSplits: 1).map(String.init)
        let subCommand = components.first ?? "help"
        let param = components.count > 1 ? components[1] : ""
        
        switch subCommand {
        case "list":
            let status = await MCPService.shared.getStatusReport()
            await viewModel.appendSystemMessage(status)
            return .handled
            
        case "install":
            if param.lowercased().hasPrefix("vision") {
                // usage: /mcp install vision <api_key>
                let parts = param.split(separator: " ")
                if parts.count >= 2 {
                    let apiKey = String(parts[1])
                    await MCPService.shared.installVisionMCP(apiKey: apiKey)
                    await viewModel.appendSystemMessage("Installing and connecting to Vision MCP Server...")
                } else {
                    return .error("Usage: /mcp install vision <api_key>")
                }
            } else {
                return .error("Unknown install target. Currently only 'vision' is supported via command.")
            }
            return .handled
            
        default:
             await viewModel.appendSystemMessage("""
            **MCP Commands:**
            - `/mcp list`: Show connected servers and tools.
            - `/mcp install vision <api_key>`: Install Vision MCP Server.
            """)
            return .handled
        }
    }
}
