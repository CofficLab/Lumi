import Combine
import Foundation
import SwiftUI
import OSLog
import MagicKit

struct CommandSuggestion: Identifiable, Equatable {
    let id = UUID()
    let command: String
    let description: String
    let category: String
}

/// 命令建议视图模型 - 提供斜杠命令自动补全功能
@MainActor
class CommandSuggestionViewModel: ObservableObject, SuperLog {
    nonisolated static let verbose = true
    nonisolated static let emoji = "🔍"
    
    @Published private(set) var suggestions: [CommandSuggestion] = []
    @Published private(set) var isVisible: Bool = false
    @Published private(set) var selectedIndex: Int = 0

    /// Slash 命令服务引用（弱引用避免循环）
    weak var slashCommandService: SlashCommandService?
    
    /// 静态命令（当服务不可用或没有项目命令时使用）
    private let staticCommands: [CommandSuggestion] = [
        CommandSuggestion(command: "/clear", description: "Clear chat history", category: "System"),
        CommandSuggestion(command: "/help", description: "Show all available commands", category: "System"),
        CommandSuggestion(command: "/plan", description: "Generate implementation plan", category: "Productivity"),
        CommandSuggestion(command: "/mcp list", description: "List connected MCP servers", category: "MCP"),
        CommandSuggestion(command: "/mcp install vision", description: "Install Vision MCP Server", category: "MCP"),
        CommandSuggestion(command: "/commands", description: "List all available commands", category: "System"),
    ]

    init(slashCommandService: SlashCommandService? = nil) {
        self.slashCommandService = slashCommandService
        // 初始显示静态命令
        self.suggestions = staticCommands
    }
    
    /// 设置 Slash 命令服务
    func setSlashCommandService(_ service: SlashCommandService) {
        self.slashCommandService = service
    }

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

        // 始终显示静态命令作为基础
        var allSuggestions = staticCommands

        // 如果有服务，异步获取动态命令并追加
        if let service = slashCommandService {
            Task {
                let dynamicInfos = await service.getSuggestions(for: input)

                if Self.verbose {
                    os_log("\(Self.t) 找到 \(dynamicInfos.count) 个动态建议", )
                }

                // 将 SlashCommandInfo 转换为 CommandSuggestion
                let dynamicSuggestions = dynamicInfos.map { info in
                    CommandSuggestion(command: info.name, description: info.description, category: info.category)
                }

                await MainActor.run {
                    // 合并静态命令和动态命令
                    // 过滤掉重复的命令（如果动态命令包含静态命令）
                    let dynamicOnly = dynamicSuggestions.filter { dynamic in
                        !staticCommands.contains { $0.command == dynamic.command }
                    }

                    if dynamicOnly.isEmpty {
                        // 如果没有额外的动态命令，只显示静态命令（按输入过滤）
                        let filtered = staticCommands.filter { $0.command.lowercased().hasPrefix(lowercasedInput) }
                        setSuggestions(filtered)
                    } else {
                        // 合并静态和动态命令
                        var combined = staticCommands
                        combined.append(contentsOf: dynamicOnly)
                        // 按输入过滤
                        let filtered = combined.filter { $0.command.lowercased().hasPrefix(lowercasedInput) }
                        setSuggestions(filtered)
                    }

                    setIsVisible(!suggestions.isEmpty)
                    setSelectedIndex(0)

                    if Self.verbose {
                        os_log("\(Self.t) 显示 \(self.suggestions.count) 个建议", )
                    }
                }
            }
        } else {
            // 没有服务时只使用静态命令
            let filtered = staticCommands.filter { $0.command.lowercased().hasPrefix(lowercasedInput) }
            setSuggestions(filtered)
            setIsVisible(!suggestions.isEmpty)
            setSelectedIndex(0)
        }
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
