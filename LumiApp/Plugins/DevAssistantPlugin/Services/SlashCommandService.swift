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
            
        default:
            return .error("Unknown command: /\(command)")
        }
    }
}
