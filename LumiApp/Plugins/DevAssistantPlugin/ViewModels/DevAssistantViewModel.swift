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
    @Published var depthWarning: DepthWarning?
    
    // MARK: - 命令建议
    @Published var commandSuggestionViewModel = CommandSuggestionViewModel()
    
    // MARK: - 工具队列

    private var pendingToolCalls: [ToolCall] = []
    private var currentDepth: Int = 0

    // MARK: - 项目信息

    @Published var currentProjectName: String = ""
    @Published var currentProjectPath: String = ""
    @Published var isProjectSelected: Bool = false

    // MARK: - 风险控制

    @Published var autoApproveRisk: Bool = {
        // 从 UserDefaults 加载保存的值
        let saved = UserDefaults.standard.bool(forKey: "DevAssistant_AutoApproveRisk")
        // 如果不存在，默认为 false
        return saved
    }() {
        didSet {
            UserDefaults.standard.set(autoApproveRisk, forKey: "DevAssistant_AutoApproveRisk")
            if Self.verbose {
                os_log("\(self.t)自动批准风险已更改: \(self.autoApproveRisk)")
            }
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

    // MARK: - 提示词服务

    let promptService = PromptService.shared

    // MARK: - 图片上传
    
    func handleImageUpload(url: URL) {
        // 读取图片数据
        guard let data = try? Data(contentsOf: url),
              let _ = NSImage(data: data) else {
            errorMessage = "Invalid image file"
            return
        }
        
        // 创建包含图片的消息
        // 这里需要扩展 ChatMessage 支持图片，或者在 content 中以特定格式标记
        // Claude 支持 content 为数组，包含 text 和 image
        // 目前我们的 ChatMessage.content 是 String
        // 我们可以暂时将其作为用户消息发送，并在发送时特殊处理
        
        // 临时方案：将图片转换为 base64 并嵌入到 content 中（如果后端支持）
        // 或者修改 ChatMessage 结构
        
        // 由于需要查看 Claude code 的实现，通常是将图片作为 message content 的一部分
        // 我们这里先简单处理，假设我们将在 sendMessage 时处理图片
        
        let base64 = data.base64EncodedString()
        let mimeType = url.pathExtension.lowercased() == "png" ? "image/png" : "image/jpeg"
        
        // 构造一个特殊的标记，让 LLMProvider 在构建请求时解析
        // 格式: [IMAGE_BASE64:<mime_type>:<data>]
        let imageMarker = "[IMAGE_BASE64:\(mimeType):\(base64)]"
        
        // 添加到当前输入框或直接发送
        // 这里选择直接添加到输入框，让用户可以附带文字
        // 但 base64 太长，不适合在输入框显示
        // 我们应该在 ViewModel 中维护一个 pendingAttachments
        
        pendingAttachments.append(.image(data: data, mimeType: mimeType, url: url))
    }
    
    // 附件枚举
    enum Attachment {
        case image(data: Data, mimeType: String, url: URL)
    }
    
    @Published var pendingAttachments: [Attachment] = []
    // MARK: - 工具
    
    private let builtInTools: [AgentTool]
    private var tools: [AgentTool] = []
    
    private let mcpService = MCPService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - 初始化
    
    init() {
        // 初始化工具
        self.builtInTools = [
            ListDirectoryTool(),
            ReadFileTool(),
            WriteFileTool(),
            ShellTool(shellService: .shared),
        ]
        self.tools = self.builtInTools
        
        // 订阅 MCP 工具更新
        mcpService.$tools
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mcpTools in
                guard let self = self else { return }
                self.tools = self.builtInTools + mcpTools
                if Self.verbose {
                    os_log("\(self.t)工具列表已更新，当前共 \(self.tools.count) 个工具 (MCP: \(mcpTools.count))")
                }
            }
            .store(in: &cancellables)

        // 加载语言偏好
        loadLanguagePreference()

        // 订阅输入变化以更新建议
        $currentInput
            .receive(on: RunLoop.main)
            .sink { [weak self] input in
                self?.commandSuggestionViewModel.updateSuggestions(for: input)
            }
            .store(in: &cancellables)
            
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
            os_log("\(self.t)自动批准风险设置: \(self.autoApproveRisk)")
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
        guard !currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !pendingAttachments.isEmpty else { return }

        if Self.verbose {
            os_log("\(self.t)用户发送消息")
        }

        // 清除之前的深度警告
        depthWarning = nil

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
                    self.pendingAttachments.removeAll()
                case let .error(msg):
                    messages.append(ChatMessage(role: .assistant, content: "Command Error: \(msg)", isError: true))
                    isProcessing = false
                    self.pendingAttachments.removeAll()
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
        var finalContent = content
        
        // 处理附件
        if !pendingAttachments.isEmpty {
            var attachmentsText = ""
            for attachment in pendingAttachments {
                if case .image(let data, let mimeType, _) = attachment {
                    let base64 = data.base64EncodedString()
                    attachmentsText += "[IMAGE_BASE64:\(mimeType):\(base64)]\n"
                }
            }
            finalContent = attachmentsText + finalContent
            pendingAttachments.removeAll()
        }
        
        let userMsg = ChatMessage(role: .user, content: finalContent)
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
            if Self.verbose {
                os_log("\(self.t)继续处理下一个工具: \(nextTool.name)")
            }
            await handleToolCall(nextTool)
        } else {
            if Self.verbose {
                os_log("\(self.t)所有工具处理完成，继续对话")
            }
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
        let maxDepth = 10

        guard depth < maxDepth else {
            errorMessage = "Max recursion depth reached."
            isProcessing = false
            depthWarning = DepthWarning(currentDepth: depth, maxDepth: maxDepth, warningType: .reached)
            os_log(.error, "\(self.t)达到最大递归深度 (\(maxDepth))，对话终止")
            return
        }

        currentDepth = depth
        if Self.verbose {
            os_log("\(self.t)开始处理对话轮次 (深度: \(depth))")
        }

        // 更新深度警告状态
        updateDepthWarning(currentDepth: depth, maxDepth: maxDepth)

        do {
            let config = getCurrentConfig()

            if Self.verbose {
                os_log("\(self.t)调用 LLM (供应商: \(config.providerId), 模型: \(config.model))")
            }

            // 1. 获取 LLM 响应
            let responseMsg = try await llmService.sendMessage(messages: messages, config: config, tools: tools)
            messages.append(responseMsg)

            // 2. 检查工具调用
            if let toolCalls = responseMsg.toolCalls, !toolCalls.isEmpty {
                if Self.verbose {
                    os_log("\(self.t)收到 \(toolCalls.count) 个工具调用，开始执行")
                }
                pendingToolCalls = toolCalls

                // 开始处理第一个工具
                let firstTool = pendingToolCalls.removeFirst()
                await handleToolCall(firstTool)
            } else {
                // 无工具调用，轮次结束
                isProcessing = false
                if Self.verbose {
                    os_log("\(self.t)✅ 对话轮次已完成（无工具调用）")
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            messages.append(ChatMessage(role: .assistant, content: "Error: \(error.localizedDescription)", isError: true))
            isProcessing = false
            depthWarning = nil  // 清除深度警告
            os_log(.error, "\(self.t)对话处理失败: \(error.localizedDescription)")
        }
    }

    // MARK: - 深度警告管理

    /// 更新深度警告状态
    /// 更新深度警告状态
    private func updateDepthWarning(currentDepth: Int, maxDepth: Int) {
        if currentDepth >= maxDepth - 1 {
            depthWarning = DepthWarning(currentDepth: currentDepth, maxDepth: maxDepth, warningType: .critical)
        } else if currentDepth >= 7 {
            depthWarning = DepthWarning(currentDepth: currentDepth, maxDepth: maxDepth, warningType: .approaching)
        } else {
            depthWarning = nil  // 清除警告
        }
    }

    /// 清除深度警告（用户手动关闭）
    func dismissDepthWarning() {
        depthWarning = nil
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
