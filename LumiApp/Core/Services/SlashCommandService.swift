import Foundation
import MagicKit
import OSLog

enum SlashCommandResult {
    case handled
    case notHandled
    case error(String)
}

/// 斜杠命令服务 - 处理内置命令和项目命令
actor SlashCommandService: SuperLog {
    nonisolated static let emoji = "⌨️"
    nonisolated static let verbose = true
    
    /// 内置命令列表
    private let builtInCommands = ["clear", "help", "plan", "mcp"]
    
    /// 项目命令加载器
    private let commandExecutor: ProjectCommandExecutor
    
    /// 当前项目路径
    private var currentProjectPath: String?
    
    init() {
        self.commandExecutor = ProjectCommandExecutor()
    }
    
    // MARK: - 公开 API
    
    /// 设置当前项目路径并重新加载命令
    func setCurrentProjectPath(_ path: String?) async {
        currentProjectPath = path
        
        if let projectPath = path {
            await commandExecutor.reloadCommands(for: projectPath)
            if Self.verbose {
                os_log("\(Self.t)📚 已为项目重新加载命令：\(projectPath)")
            }
        }
    }
    
    /// 检查是否为支持的斜杠命令（包括内置命令和项目命令）
    func isSlashCommand(_ input: String) async -> Bool {
        guard input.hasPrefix("/") else { return false }
        
        let command = input.dropFirst().split(separator: " ", maxSplits: 1).first.map(String.init) ?? ""
        
        // 检查内置命令
        if builtInCommands.contains(command) {
            return true
        }
        
        // 检查项目命令
        return await commandExecutor.isSlashCommand(input)
    }
    
    /// 获取所有可用命令（用于帮助和自动补全）
    func getAllCommands() async -> [SlashCommandInfo] {
        var commands: [SlashCommandInfo] = []
        
        // 添加内置命令
        commands.append(contentsOf: getBuiltInCommandInfo())
        
        // 添加项目命令
        let projectCommands = await commandExecutor.getAllCommands()
        for cmd in projectCommands {
            commands.append(SlashCommandInfo(
                name: cmd.slashCommand,
                description: cmd.description,
                category: categoryForSource(cmd.source)
            ))
        }
        
        return commands
    }
    
    /// 获取命令建议（用于自动补全）
    func getSuggestions(for input: String) async -> [CommandSuggestion] {
        var suggestions: [CommandSuggestion] = []
        
        // 内置命令建议
        if input.hasPrefix("/") {
            let lowercasedInput = input.lowercased()
            let builtInSuggestions = getBuiltInCommandInfo().filter {
                $0.name.lowercased().hasPrefix(lowercasedInput)
            }.map {
                CommandSuggestion(command: $0.name, description: $0.description, category: $0.category)
            }
            suggestions.append(contentsOf: builtInSuggestions)
        }
        
        // 项目命令建议
        let projectSuggestions = await commandExecutor.getSuggestions(for: input)
        suggestions.append(contentsOf: projectSuggestions)
        
        return suggestions
    }
    
    /// Handle slash command with AgentProvider
    func handle(input: String, provider: AgentProvider) async -> SlashCommandResult {
        guard input.hasPrefix("/") else { return .notHandled }

        let components = input.dropFirst().split(separator: " ", maxSplits: 1).map(String.init)
        guard let command = components.first else { return .notHandled }
        let arguments = components.count > 1 ? components[1] : ""

        // 优先处理内置命令
        switch command {
        case "clear":
            await provider.clearHistory()
            return .handled

        case "help":
            return await handleHelpCommand(provider: provider)

        case "plan":
            if arguments.isEmpty {
                return .error("Usage: /plan [task description]")
            }
            await provider.triggerPlanningMode(task: arguments)
            return .handled

        case "mcp":
            return await handleMCPCommand(args: arguments, provider: provider, toolsViewModel: provider.toolsViewModel)
        
        case "commands", "cmd":
            // 显示所有可用命令
            return await handleCommandsCommand(provider: provider)
            
        default:
            break
        }
        
        // 尝试执行项目命令
        if await commandExecutor.isSlashCommand(input) {
            return await commandExecutor.executeSlashCommand(input, provider: provider)
        }

        // 不支持的命令
        return .notHandled
    }
    
    // MARK: - 内置命令处理
    
    private func getBuiltInCommandInfo() -> [SlashCommandInfo] {
        return [
            SlashCommandInfo(name: "/clear", description: "Clear chat history and reset context", category: "System"),
            SlashCommandInfo(name: "/help", description: "Show all available commands", category: "System"),
            SlashCommandInfo(name: "/plan", description: "Generate a detailed implementation plan for a task", category: "Productivity"),
            SlashCommandInfo(name: "/mcp", description: "Manage MCP servers and tools", category: "MCP"),
            SlashCommandInfo(name: "/commands", description: "List all available commands (built-in + project)", category: "System"),
        ]
    }
    
    private func handleHelpCommand(provider: AgentProvider) async -> SlashCommandResult {
        let commands = await getAllCommands()
        
        // 按类别分组
        var grouped: [String: [SlashCommandInfo]] = [:]
        for cmd in commands {
            if grouped[cmd.category] == nil {
                grouped[cmd.category] = []
            }
            grouped[cmd.category]?.append(cmd)
        }
        
        var message = "**Available Commands:**\n\n"
        
        for (category, cmds) in grouped.sorted(by: { $0.key < $1.key }) {
            message += "### \(category)\n"
            for cmd in cmds.sorted(by: { $0.name < $1.name }) {
                message += "- **\(cmd.name)**: \(cmd.description)\n"
            }
            message += "\n"
        }
        
        message += """
        
        ---
        💡 **Tips:**
        - Type `/` to see command suggestions
        - Project commands are loaded from `.agent/commands/` directory
        - User commands are loaded from `~/.agent/commands/` directory
        """
        
        await provider.appendSystemMessage(message)
        return .handled
    }
    
    private func handleCommandsCommand(provider: AgentProvider) async -> SlashCommandResult {
        return await handleHelpCommand(provider: provider)
    }
    
    private func handleMCPCommand(args: String, provider: AgentProvider, toolsViewModel: ToolsViewModel) async -> SlashCommandResult {
        let components = args.split(separator: " ", maxSplits: 1).map(String.init)
        let subCommand = components.first ?? "help"
        let param = components.count > 1 ? components[1] : ""

        switch subCommand {
        case "list":
            let status = await MainActor.run {
                toolsViewModel.getStatusReport()
            }
            await provider.appendSystemMessage(status)
            return .handled

        case "install":
            if param.lowercased().hasPrefix("vision") {
                let parts = param.split(separator: " ")
                if parts.count >= 2 {
                    let apiKey = String(parts[1])
                    await MainActor.run {
                        toolsViewModel.installVisionMCP(apiKey: apiKey)
                    }
                    await provider.appendSystemMessage("Installing and connecting to Vision MCP Server...")
                } else {
                    return .error("Usage: /mcp install vision <api_key>")
                }
            } else {
                return .error("Unknown install target. Currently only 'vision' is supported via command.")
            }
            return .handled

        default:
             await provider.appendSystemMessage("""
            **MCP Commands:**
            - `/mcp list`: Show connected servers and tools.
            - `/mcp install vision <api_key>`: Install Vision MCP Server.
            """)
            return .handled
        }
    }
    
    // MARK: - Helper Methods
    
    private func categoryForSource(_ source: ProjectCommand.Source) -> String {
        switch source {
        case .project:
            return "Project"
        case .user:
            return "User"
        case .plugin:
            return "Plugin"
        }
    }
}

/// 命令信息模型（用于帮助显示）
struct SlashCommandInfo {
    let name: String
    let description: String
    let category: String
}
