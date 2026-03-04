import Combine
import Foundation
import SwiftUI

struct CommandSuggestion: Identifiable {
    let id = UUID()
    let command: String
    let description: String
    let category: String
}

/// 命令建议视图模型 - 提供斜杠命令自动补全功能
@MainActor
class CommandSuggestionViewModel: ObservableObject {
    /// 全局单例
    static let shared = CommandSuggestionViewModel()

    @Published private(set) var suggestions: [CommandSuggestion] = []
    @Published private(set) var isVisible: Bool = false
    @Published private(set) var selectedIndex: Int = 0

    private let allCommands: [CommandSuggestion] = [
        // Built-in commands
        CommandSuggestion(command: "/clear", description: "Clear chat history", category: "System"),
        CommandSuggestion(command: "/help", description: "Show help message", category: "System"),
        CommandSuggestion(command: "/plan", description: "Generate implementation plan", category: "Productivity"),

        // MCP commands
        CommandSuggestion(command: "/mcp list", description: "List connected MCP servers", category: "MCP"),
        CommandSuggestion(command: "/mcp install vision", description: "Install Vision MCP Server", category: "MCP"),
    ]

    private init() {}

    // MARK: - Set Methods

    func setSuggestions(_ suggestions: [CommandSuggestion]) {
        self.suggestions = suggestions
    }

    func setIsVisible(_ isVisible: Bool) {
        self.isVisible = isVisible
    }

    func setSelectedIndex(_ selectedIndex: Int) {
        guard selectedIndex >= 0 else {
            self.selectedIndex = 0
            return
        }
        self.selectedIndex = selectedIndex
    }

    // MARK: - Business Logic

    func updateSuggestions(for input: String) {
        guard input.hasPrefix("/") else {
            setIsVisible(false)
            return
        }

        let lowercasedInput = input.lowercased()

        if lowercasedInput == "/" {
            setSuggestions(allCommands)
        } else {
            let filtered = allCommands.filter { $0.command.lowercased().hasPrefix(lowercasedInput) }
            setSuggestions(filtered)
        }

        setIsVisible(!suggestions.isEmpty)
        setSelectedIndex(0)
    }

    func selectNext() {
        guard !suggestions.isEmpty else { return }
        let nextIndex = (selectedIndex + 1) % suggestions.count
        setSelectedIndex(nextIndex)
    }

    func selectPrevious() {
        guard !suggestions.isEmpty else { return }
        let previousIndex = (selectedIndex - 1 + suggestions.count) % suggestions.count
        setSelectedIndex(previousIndex)
    }

    func getCurrentSuggestion() -> CommandSuggestion? {
        guard isVisible, !suggestions.isEmpty, selectedIndex < suggestions.count else { return nil }
        return suggestions[selectedIndex]
    }
}
