
import Foundation
import SwiftUI
import Combine

struct CommandSuggestion: Identifiable {
    let id = UUID()
    let command: String
    let description: String
    let category: String
}

@MainActor
class CommandSuggestionViewModel: ObservableObject {
    @Published var suggestions: [CommandSuggestion] = []
    @Published var isVisible: Bool = false
    @Published var selectedIndex: Int = 0
    
    private let allCommands: [CommandSuggestion] = [
        // Built-in commands
        CommandSuggestion(command: "/clear", description: "Clear chat history", category: "System"),
        CommandSuggestion(command: "/help", description: "Show help message", category: "System"),
        CommandSuggestion(command: "/plan", description: "Generate implementation plan", category: "Productivity"),
        
        // MCP commands
        CommandSuggestion(command: "/mcp list", description: "List connected MCP servers", category: "MCP"),
        CommandSuggestion(command: "/mcp install vision", description: "Install Vision MCP Server", category: "MCP")
    ]
    
    func updateSuggestions(for input: String) {
        guard input.hasPrefix("/") else {
            isVisible = false
            return
        }
        
        let lowercasedInput = input.lowercased()
        
        if lowercasedInput == "/" {
            suggestions = allCommands
        } else {
            suggestions = allCommands.filter { $0.command.lowercased().hasPrefix(lowercasedInput) }
        }
        
        isVisible = !suggestions.isEmpty
        selectedIndex = 0
    }
    
    func selectNext() {
        guard !suggestions.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % suggestions.count
    }
    
    func selectPrevious() {
        guard !suggestions.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + suggestions.count) % suggestions.count
    }
    
    func getCurrentSuggestion() -> CommandSuggestion? {
        guard isVisible, !suggestions.isEmpty, selectedIndex < suggestions.count else { return nil }
        return suggestions[selectedIndex]
    }
}
