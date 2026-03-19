import Foundation
import MagicKit
/// 斜杠命令信息
struct SlashCommandInfo {
    let name: String
    let description: String
    let category: String
}

/// 斜杠命令执行结果
enum SlashCommandResult {
    /// 命令已处理，无需额外操作
    case handled
    /// 命令未处理
    case notHandled
    /// 执行出错
    case error(String)
    /// 需要添加系统消息（如帮助信息）
    case systemMessage(String)
    /// 需要添加用户消息并触发 AI 处理（如项目命令）
    case userMessage(String, triggerProcessing: Bool)
    /// 清空历史记录
    case clearHistory
    /// 触发规划模式
    case triggerPlanning(String)
    /// 执行 MCP 命令
    case mcpCommand(subCommand: String, param: String)
}

/// 斜杠命令服务 - 处理内置命令和项目命令
/// 只负责命令解析和执行，不直接操作消息，返回结果由调用方处理
actor SlashCommandService: SuperLog {
    nonisolated static let emoji = "⌨️"
    nonisolated static let verbose = false

    /// 内置命令列表
    private let builtInCommands = ["clear", "help", "plan", "mcp"]

    /// 项目命令执行器
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
                AppLogger.core.info("\(Self.t)📚 已为项目重新加载命令：\(projectPath)")
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
    func getSuggestions(for input: String) async -> [SlashCommandInfo] {
        var suggestions: [SlashCommandInfo] = []

        // 内置命令建议
        if input.hasPrefix("/") {
            let lowercasedInput = input.lowercased()
            let builtInSuggestions = getBuiltInCommandInfo().filter {
                $0.name.lowercased().hasPrefix(lowercasedInput)
            }
            suggestions.append(contentsOf: builtInSuggestions)
        }

        // 项目命令建议
        let projectCommands = await commandExecutor.getAllCommands()
        let filteredProjectCommands = projectCommands.filter { cmd in
            cmd.slashCommand.lowercased().hasPrefix(input.lowercased())
        }
        for cmd in filteredProjectCommands {
            suggestions.append(SlashCommandInfo(
                name: cmd.slashCommand,
                description: cmd.description,
                category: categoryForSource(cmd.source)
            ))
        }

        return suggestions
    }

    /// 处理斜杠命令
    /// - Parameter input: 用户输入（如 "/help"）
    /// - Returns: 命令执行结果，由调用方决定如何处理
    func handle(input: String) async -> SlashCommandResult {
        guard input.hasPrefix("/") else { return .notHandled }

        let components = input.dropFirst().split(separator: " ", maxSplits: 1).map(String.init)
        guard let command = components.first else { return .notHandled }
        let arguments = components.count > 1 ? components[1] : ""

        // 优先处理内置命令
        switch command {
        case "clear":
            return .clearHistory

        case "help", "commands", "cmd":
            return await buildHelpResult()

        case "plan":
            if arguments.isEmpty {
                return .error("Usage: /plan [task description]")
            }
            return .triggerPlanning(arguments)

        case "mcp":
            let mcpComponents = arguments.split(separator: " ", maxSplits: 1).map(String.init)
            let subCommand = mcpComponents.first ?? "help"
            let param = mcpComponents.count > 1 ? mcpComponents[1] : ""
            return .mcpCommand(subCommand: subCommand, param: param)

        default:
            break
        }

        // 尝试执行项目命令
        if await commandExecutor.isSlashCommand(input) {
            return await commandExecutor.executeSlashCommand(input)
        }

        // 不支持的命令
        return .notHandled
    }
}

// MARK: - 私有方法

extension SlashCommandService {
    /// 获取内置命令信息
    private func getBuiltInCommandInfo() -> [SlashCommandInfo] {
        return [
            SlashCommandInfo(name: "/clear", description: "Clear chat history and reset context", category: "System"),
            SlashCommandInfo(name: "/help", description: "Show all available commands", category: "System"),
            SlashCommandInfo(name: "/plan", description: "Generate a detailed implementation plan for a task", category: "Productivity"),
            SlashCommandInfo(name: "/mcp", description: "Manage MCP servers and tools", category: "MCP"),
            SlashCommandInfo(name: "/commands", description: "List all available commands (built-in + project)", category: "System"),
        ]
    }

    /// 构建帮助信息结果
    private func buildHelpResult() async -> SlashCommandResult {
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

        return .systemMessage(message)
    }

    /// 根据命令来源返回类别名称
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
