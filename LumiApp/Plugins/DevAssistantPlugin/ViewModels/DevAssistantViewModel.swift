import Combine
import Foundation
import SwiftUI
import MagicKit
import OSLog

/// DevAssistant 视图模型
@MainActor
class DevAssistantViewModel: ObservableObject, SuperLog {
    nonisolated static let emoji = "🤖"
    nonisolated static let verbose = true

    // MARK: - 发布状态

    @Published var messages: [ChatMessage] = []
    @Published var currentInput: String = ""
    @Published var isProcessing: Bool = false
    @Published var errorMessage: String?
    @Published var pendingPermissionRequest: PermissionRequest?

    // MARK: - 项目信息

    @Published var currentProjectName: String = ""
    @Published var currentProjectPath: String = ""
    @Published var isProjectSelected: Bool = false
    
    // MARK: - 风险控制
    
    @Published var autoApproveRisk: Bool = false {
        didSet {
            UserDefaults.standard.set(autoApproveRisk, forKey: "DevAssistant_AutoApproveRisk")
        }
    }

    // MARK: - 语言偏好

    @Published var languagePreference: LanguagePreference = .chinese {
        didSet {
            if Self.verbose {
                os_log("\(self.t)切换语言偏好: \(self.languagePreference.displayName)")
            }
            // 保存到 UserDefaults
            if let encoded = try? JSONEncoder().encode(self.languagePreference) {
                UserDefaults.standard.set(encoded, forKey: "DevAssistant_LanguagePreference")
            }
            // 通知语言切换
            notifyLanguageChange()
        }
    }

    // MARK: - 供应商选择

    @Published var selectedProviderId: String = "anthropic" {
        didSet {
            if Self.verbose {
                os_log("\(self.t)切换供应商: \(self.selectedProviderId)")
            }
        }
    }

    // MARK: - 供应商注册表

    private let registry = ProviderRegistry.shared
    private let llmService = LLMService.shared

    // MARK: - 可用供应商信息

    var availableProviders: [ProviderInfo] {
        registry.allProviders()
    }

    // MARK: - 工具队列

    private var pendingToolCalls: [ToolCall] = []
    private var currentDepth: Int = 0

    // MARK: - 提示词服务

    let promptService = PromptService.shared

    // MARK: - 工具

    private let tools: [AgentTool]

    // MARK: - 初始化

    init() {
        // 初始化工具
        self.tools = [
            ListDirectoryTool(),
            ReadFileTool(),
            WriteFileTool(),
            ShellTool(shellService: .shared),
        ]

        // 加载语言偏好
        loadLanguagePreference()

        // 初始化上下文和历史
        Task {
            // 默认不设置项目根目录，等待用户选择
            await loadProjectSettings()

            let fullSystemPrompt = await promptService.buildSystemPrompt(
                languagePreference: languagePreference,
                includeContext: isProjectSelected
            )

            messages.append(ChatMessage(role: .system, content: fullSystemPrompt))

            // 如果未选择项目，显示引导消息
            if !isProjectSelected {
                showProjectSelectionPrompt()
            } else {
                let welcomeMsg = await promptService.getWelcomeBackMessage(
                    projectName: currentProjectName,
                    projectPath: currentProjectPath,
                    language: languagePreference
                )
                messages.append(ChatMessage(role: .assistant, content: welcomeMsg))
            }
        }

        if Self.verbose {
            os_log("\(self.t)DevAssistant 视图模型已初始化")
        }
    }

    // MARK: - 项目选择提示

    private func showProjectSelectionPrompt() {
        Task {
            let prompt = await promptService.getWelcomeMessage()
            messages.append(ChatMessage(role: .assistant, content: prompt))
        }
    }

    // MARK: - 项目管理

    private func loadProjectSettings() async {
        // 从 UserDefaults 加载上次选择的项目
        if let savedPath = UserDefaults.standard.string(forKey: "DevAssistant_SelectedProject"),
           !savedPath.isEmpty {
            let rootURL = URL(fileURLWithPath: savedPath)

            // 验证项目路径是否仍然有效
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: savedPath, isDirectory: &isDirectory) && isDirectory.boolValue {
                self.currentProjectName = rootURL.lastPathComponent
                self.currentProjectPath = savedPath
                self.isProjectSelected = true

                // 获取并应用项目配置（包括模型选择）
                let config = ProjectConfigStore.shared.getOrCreateConfig(for: savedPath)
                applyProjectConfig(config)

                await ContextService.shared.setProjectRoot(rootURL)

                if Self.verbose {
                    os_log("\(self.t)已加载项目: \(self.currentProjectName)")
                    os_log("\(self.t)项目配置: 供应商=\(config.providerId), 模型=\(config.model)")
                }
            } else {
                // 项目路径无效，清除设置
                clearProjectSettings()
            }
        }
    }

    func switchProject(to path: String) async {
        let rootURL = URL(fileURLWithPath: path)
        
        // 验证路径是否存在
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
            self.errorMessage = "项目路径无效: \(path)"
            return
        }
        
        await ContextService.shared.setProjectRoot(rootURL)
        self.currentProjectName = rootURL.lastPathComponent
        self.currentProjectPath = path
        self.isProjectSelected = true
        
        // 保存到 UserDefaults
        UserDefaults.standard.set(path, forKey: "DevAssistant_SelectedProject")
        
        // 添加到最近项目列表
        addToRecentProjects(name: rootURL.lastPathComponent, path: path)

        // 刷新上下文
        let fullSystemPrompt = await promptService.buildSystemPrompt(
            languagePreference: languagePreference,
            includeContext: true
        )

        // 重建消息历史
        messages = [ChatMessage(role: .system, content: fullSystemPrompt)]
        let switchMsg = await promptService.getProjectSwitchedMessage(
            projectName: currentProjectName,
            projectPath: currentProjectPath
        )
        messages.append(ChatMessage(role: .assistant, content: switchMsg))

        if Self.verbose {
            os_log("\(self.t)已切换到项目: \(self.currentProjectName)")
        }
    }

    func clearProjectSettings() {
        UserDefaults.standard.removeObject(forKey: "DevAssistant_SelectedProject")
        self.currentProjectName = ""
        self.currentProjectPath = ""
        self.isProjectSelected = false
        
        Task {
            await ContextService.shared.setProjectRoot(nil)
        }
    }

    private func addToRecentProjects(name: String, path: String) {
        var recentProjects: [RecentProject] = []
        
        // 加载现有最近项目
        if let data = UserDefaults.standard.data(forKey: "RecentProjects"),
           let decoded = try? JSONDecoder().decode([RecentProject].self, from: data) {
            recentProjects = decoded
        }
        
        // 移除重复项
        recentProjects.removeAll { $0.path == path }
        
        // 添加新项目到开头
        let newProject = RecentProject(name: name, path: path, lastUsed: Date())
        recentProjects.insert(newProject, at: 0)
        
        // 只保留最近 5 个
        recentProjects = Array(recentProjects.prefix(5))
        
        // 保存
        if let encoded = try? JSONEncoder().encode(recentProjects) {
            UserDefaults.standard.set(encoded, forKey: "RecentProjects")
        }
    }

    // MARK: - 消息发送

    func sendMessage() {
        guard !currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // 检查是否已选择项目
        if !isProjectSelected {
            Task {
                let warningContent = await promptService.getProjectNotSelectedWarningMessage()
                let warningMsg = ChatMessage(
                    role: .assistant,
                    content: warningContent,
                    isError: true
                )
                messages.append(warningMsg)
            }
            return
        }

        let input = currentInput
        currentInput = ""
        isProcessing = true
        errorMessage = nil

        // 检查是否为斜杠命令
        if input.hasPrefix("/") {
            Task {
                let result = await SlashCommandService.shared.handle(input: input, viewModel: self)
                switch result {
                case .handled:
                    isProcessing = false
                case let .error(msg):
                    messages.append(ChatMessage(role: .assistant, content: "Command Error: \(msg)", isError: true))
                    isProcessing = false
                case .notHandled:
                    await processUserMessage(input)
                }
            }
            return
        }

        Task {
            await processUserMessage(input)
        }
    }

    private func processUserMessage(_ content: String) async {
        let userMsg = ChatMessage(role: .user, content: content)
        messages.append(userMsg)

        await processTurn()
    }

    // MARK: - 权限处理

    /// 解析工具调用参数
    private func parseArguments(_ argumentsString: String) -> [String: Any] {
        if let data = argumentsString.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return json
        }
        return [:]
    }

    func respondToPermissionRequest(allowed: Bool) {
        guard let request = pendingPermissionRequest else { return }

        pendingPermissionRequest = nil

        Task {
            if allowed {
                await executePendingTool(request: request)
            } else {
                messages.append(ChatMessage(
                    role: .user,
                    content: "Tool execution denied by user.",
                    toolCallID: request.toolCallID
                ))
                await processPendingTools()
            }
        }
    }

    private func executePendingTool(request: PermissionRequest) async {
        guard let tool = tools.first(where: { $0.name == request.toolName }) else {
            messages.append(ChatMessage(
                role: .user,
                content: "Error: Tool '\(request.toolName)' not found.",
                toolCallID: request.toolCallID
            ))
            await processPendingTools()
            return
        }

        do {
            let result = try await tool.execute(arguments: request.arguments)

            messages.append(ChatMessage(
                role: .user,
                content: result,
                toolCallID: request.toolCallID
            ))

            await processPendingTools()
        } catch {
            messages.append(ChatMessage(
                role: .user,
                content: "Error executing tool: \(error.localizedDescription)",
                toolCallID: request.toolCallID
            ))
            await processPendingTools()
        }
    }

    private func processPendingTools() async {
        if !pendingToolCalls.isEmpty {
            let nextTool = pendingToolCalls.removeFirst()
            await handleToolCall(nextTool)
        } else {
            await processTurn(depth: currentDepth + 1)
        }
    }

    private func handleToolCall(_ toolCall: ToolCall) async {
        // 检查权限
        // 如果开启了自动批准，或者工具不需要权限
        let requiresPermission = PermissionService.shared.requiresPermission(toolName: toolCall.name, arguments: parseArguments(toolCall.arguments))
        
        if requiresPermission && !autoApproveRisk {
            // 评估命令风险
            let riskLevel: CommandRiskLevel

            if toolCall.name == "run_command" {
                let args = parseArguments(toolCall.arguments)
                if let command = args["command"] as? String {
                    riskLevel = PermissionService.shared.evaluateCommandRisk(command: command)
                } else {
                    // 默认中风险
                    riskLevel = .medium
                }
            } else {
                // 默认中风险
                riskLevel = .medium
            }

            pendingPermissionRequest = PermissionRequest(
                toolName: toolCall.name,
                argumentsString: toolCall.arguments,
                toolCallID: toolCall.id,
                riskLevel: riskLevel
            )
            return
        }

        // 解析参数
        var arguments: [String: Any] = [:]
        if let data = toolCall.arguments.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            arguments = json
        }

        // 直接执行工具
        guard let tool = tools.first(where: { $0.name == toolCall.name }) else {
            messages.append(ChatMessage(
                role: .user,
                content: "Error: Tool '\(toolCall.name)' not found.",
                toolCallID: toolCall.id
            ))
            await processPendingTools()
            return
        }

        do {
            let result = try await tool.execute(arguments: arguments)

            messages.append(ChatMessage(
                role: .user,
                content: result,
                toolCallID: toolCall.id
            ))

            await processPendingTools()
        } catch {
            messages.append(ChatMessage(
                role: .user,
                content: "Error executing tool: \(error.localizedDescription)",
                toolCallID: toolCall.id
            ))
            await processPendingTools()
        }
    }

    // MARK: - 对话轮次处理

    private func processTurn(depth: Int = 0) async {
        guard depth < 10 else {
            errorMessage = "Max recursion depth reached."
            isProcessing = false
            return
        }

        currentDepth = depth

        do {
            let config = getCurrentConfig()

            // 1. 获取 LLM 响应
            let responseMsg = try await llmService.sendMessage(messages: messages, config: config, tools: tools)
            messages.append(responseMsg)

            // 2. 检查工具调用
            if let toolCalls = responseMsg.toolCalls, !toolCalls.isEmpty {
                pendingToolCalls = toolCalls

                // 开始处理第一个工具
                let firstTool = pendingToolCalls.removeFirst()
                await handleToolCall(firstTool)
            } else {
                // 无工具调用，轮次结束
                isProcessing = false
            }
        } catch {
            errorMessage = error.localizedDescription
            messages.append(ChatMessage(role: .assistant, content: "Error: \(error.localizedDescription)", isError: true))
            isProcessing = false
        }
    }

    // MARK: - 配置管理

    /// 获取当前供应商的配置
    private func getCurrentConfig() -> LLMConfig {
        guard let providerType = registry.providerType(forId: selectedProviderId),
              let provider = registry.createProvider(id: selectedProviderId) else {
            return LLMConfig.default
        }

        // 从 UserDefaults 获取 API Key
        let apiKey = UserDefaults.standard.string(forKey: providerType.apiKeyStorageKey) ?? ""

        // 从 UserDefaults 获取选中的模型
        let selectedModel = UserDefaults.standard.string(forKey: providerType.modelStorageKey) ?? providerType.defaultModel

        return LLMConfig(
            apiKey: apiKey,
            model: selectedModel,
            providerId: selectedProviderId
        )
    }

    /// 获取当前选中的模型名称
    var currentModel: String {
        guard let providerType = registry.providerType(forId: selectedProviderId) else {
            return ""
        }
        return UserDefaults.standard.string(forKey: providerType.modelStorageKey) ?? providerType.defaultModel
    }

    /// 更新选中供应商的模型
    func updateSelectedModel(_ model: String) {
        guard let providerType = registry.providerType(forId: selectedProviderId) else {
            return
        }
        UserDefaults.standard.set(model, forKey: providerType.modelStorageKey)
        if Self.verbose {
            os_log("\(self.t)更新模型: \(providerType.displayName) -> \(model)")
        }
    }

    /// 保存当前模型到项目配置
    func saveCurrentModelToProjectConfig() {
        guard isProjectSelected, !currentProjectPath.isEmpty else {
            return
        }

        // 获取或创建项目配置
        let config = ProjectConfigStore.shared.getOrCreateConfig(for: currentProjectPath)

        // 更新配置
        var updatedConfig = config
        updatedConfig.providerId = selectedProviderId
        updatedConfig.model = currentModel

        // 保存
        ProjectConfigStore.shared.saveConfig(updatedConfig)

        if Self.verbose {
            os_log("\(self.t)保存模型到项目配置: \(self.currentProjectName) -> \(self.currentModel)")
        }
    }

    /// 获取指定供应商的 API Key
    func getApiKey(for providerId: String) -> String {
        guard let providerType = registry.providerType(forId: providerId) else {
            return ""
        }
        return UserDefaults.standard.string(forKey: providerType.apiKeyStorageKey) ?? ""
    }

    /// 设置指定供应商的 API Key
    func setApiKey(_ apiKey: String, for providerId: String) {
        guard let providerType = registry.providerType(forId: providerId) else {
            return
        }
        UserDefaults.standard.set(apiKey, forKey: providerType.apiKeyStorageKey)
        if Self.verbose {
            os_log("\(self.t)已设置 \(providerType.displayName) 的 API Key")
        }
    }

    // MARK: - SlashCommandService API

    func appendSystemMessage(_ content: String) {
        messages.append(ChatMessage(role: .assistant, content: content))
    }

    func triggerPlanningMode(task: String) {
        Task {
            let planPrompt = await promptService.getPlanningModePrompt(task: task)
            await processUserMessage(planPrompt)
        }
    }

    // MARK: - 历史记录管理

    func clearHistory() {
        Task {
            let fullSystemPrompt = await promptService.buildSystemPrompt(
                languagePreference: languagePreference,
                includeContext: isProjectSelected
            )
            messages = [ChatMessage(role: .system, content: fullSystemPrompt)]
        }
    }

    // MARK: - 语言偏好管理

    /// 加载语言偏好
    private func loadLanguagePreference() {
        guard let data = UserDefaults.standard.data(forKey: "DevAssistant_LanguagePreference"),
              let decoded = try? JSONDecoder().decode(LanguagePreference.self, from: data) else {
            // 使用系统语言作为默认值
            let systemLanguage = Locale.current.language.languageCode?.identifier ?? "zh"
            let preferredLanguage: LanguagePreference = systemLanguage.hasPrefix("zh") ? .chinese : .english
            // 只在值不同时才设置，避免触发不必要的 didSet
            if self.languagePreference != preferredLanguage {
                self.languagePreference = preferredLanguage
            }
            return
        }
        // 只在值不同时才设置，避免触发不必要的 didSet
        if self.languagePreference != decoded {
            self.languagePreference = decoded
        }
    }

    /// 通知语言切换
    private func notifyLanguageChange() {
        Task {
            let message = await promptService.getLanguageSwitchedMessage(language: languagePreference)
            let fullSystemPrompt = await promptService.buildSystemPrompt(
                languagePreference: languagePreference,
                includeContext: isProjectSelected
            )

            // 查找并更新系统消息
            if let systemIndex = messages.firstIndex(where: { $0.role == .system }) {
                messages[systemIndex] = ChatMessage(role: .system, content: fullSystemPrompt)
            } else {
                messages.insert(ChatMessage(role: .system, content: fullSystemPrompt), at: 0)
            }

            // 添加语言切换通知
            messages.append(ChatMessage(role: .assistant, content: message))
        }
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .withNavigation(DevAssistantPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
