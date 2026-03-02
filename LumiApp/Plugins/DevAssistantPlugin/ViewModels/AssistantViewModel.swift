import Combine
import Foundation
import SwiftUI
import MagicKit
import OSLog

/// DevAssistant 视图模型
@MainActor
class AssistantViewModel: ObservableObject, SuperLog {
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
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 项目信息（镜像 AgentProvider）

    @Published var currentProjectName: String = ""
    @Published var currentProjectPath: String = ""
    @Published var isProjectSelected: Bool = false

    // MARK: - 风险控制（镜像 AgentProvider）

    @Published var autoApproveRisk: Bool = false {
        didSet {
            AgentProvider.shared.autoApproveRisk = autoApproveRisk
            if Self.verbose {
                os_log("\(self.t) 自动批准风险已更改：\(self.autoApproveRisk)")
            }
        }
    }

    // MARK: - 语言偏好（镜像 AgentProvider）

    @Published var languagePreference: LanguagePreference = .chinese {
        didSet {
            AgentProvider.shared.languagePreference = languagePreference
            if Self.verbose {
                os_log("\(self.t) 切换语言偏好：\(self.languagePreference.displayName)")
            }
            notifyLanguageChange()
        }
    }

    // MARK: - 供应商选择（镜像 AgentProvider）

    @Published var selectedProviderId: String = "anthropic" {
        didSet {
            AgentProvider.shared.selectedProviderId = selectedProviderId
            if Self.verbose {
                os_log("\(self.t) 切换供应商：\(self.selectedProviderId)")
            }
        }
    }

    // MARK: - 模型选择（镜像 AgentProvider）

    @Published var selectedModel: String = "" {
        didSet {
            AgentProvider.shared.selectedModel = selectedModel
        }
    }

    // MARK: - 聊天模式（镜像 AgentProvider）

    @Published var chatMode: ChatMode = .build {
        didSet {
            AgentProvider.shared.chatMode = chatMode
            if Self.verbose {
                os_log("\(self.t) 切换聊天模式：\(self.chatMode.displayName)")
            }
            if chatMode == .chat && oldValue == .build {
                Task {
                    await notifyModeChangeToChat()
                }
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

    // MARK: - 工具管理器（重构：关注点分离）

    /// 使用 ToolManager 管理所有工具，而不是直接管理
    private let toolManager = ToolManager.shared

    /// 获取所有可用工具（通过 ToolManager）
    private var tools: [AgentTool] {
        return toolManager.tools
    }

    // MARK: - 图片上传

    func handleImageUpload(url: URL) {
        if Self.verbose {
            os_log("\(self.t)📷 开始处理图片上传：\(url.lastPathComponent)")
        }

        // 读取图片数据
        guard let data = try? Data(contentsOf: url),
              let _ = NSImage(data: data) else {
            os_log(.error, "\(self.t)❌ 无效的图片文件")
            errorMessage = "Invalid image file"
            return
        }

        if Self.verbose {
            os_log("\(self.t)✅ 图片读取成功，大小：\(data.count) bytes")
        }

        let mimeType = url.pathExtension.lowercased() == "png" ? "image/png" : "image/jpeg"

        // 添加到待发送附件列表
        pendingAttachments.append(.image(id: UUID(), data: data, mimeType: mimeType, url: url))

        if Self.verbose {
            os_log("\(self.t)✅ 图片已添加到待发送列表，当前共 \(self.pendingAttachments.count) 个附件")
        }
    }

    // 附件枚举
    enum Attachment: Identifiable {
        case image(id: UUID, data: Data, mimeType: String, url: URL)

        var id: UUID {
            switch self {
            case .image(let id, _, _, _):
                return id
            }
        }
    }

    @Published var pendingAttachments: [Attachment] = []

    func removeAttachment(id: UUID) {
        pendingAttachments.removeAll { $0.id == id }
    }

    // MARK: - 初始化

    init() {
        // 同步 AgentProvider 的状态
        self.languagePreference = AgentProvider.shared.languagePreference
        self.chatMode = AgentProvider.shared.chatMode
        self.autoApproveRisk = AgentProvider.shared.autoApproveRisk
        self.selectedProviderId = AgentProvider.shared.selectedProviderId
        self.selectedModel = AgentProvider.shared.selectedModel
        self.currentProjectName = AgentProvider.shared.currentProjectName
        self.currentProjectPath = AgentProvider.shared.currentProjectPath
        self.isProjectSelected = AgentProvider.shared.isProjectSelected

        // 订阅输入变化以更新建议
        $currentInput
            .receive(on: RunLoop.main)
            .sink { [weak self] input in
                self?.commandSuggestionViewModel.updateSuggestions(for: input)
            }
            .store(in: &cancellables)

        // 初始化上下文和历史
        let initialLanguagePreference = languagePreference
        let initialIsProjectSelected = isProjectSelected
        let initialCurrentProjectName = currentProjectName
        let initialCurrentProjectPath = currentProjectPath

        Task { @MainActor in
            let fullSystemPrompt = await promptService.buildSystemPrompt(
                languagePreference: initialLanguagePreference,
                includeContext: initialIsProjectSelected
            )

            messages.append(ChatMessage(role: .system, content: fullSystemPrompt))

            // 如果未选择项目，显示引导消息
            if !initialIsProjectSelected {
                showProjectSelectionPrompt()
            } else {
                let welcomeMsg = await promptService.getWelcomeBackMessage(
                    projectName: initialCurrentProjectName,
                    projectPath: initialCurrentProjectPath,
                    language: initialLanguagePreference
                )
                messages.append(ChatMessage(role: .assistant, content: welcomeMsg))
            }
        }

        if Self.verbose {
            os_log("\(self.t)DevAssistant 视图模型已初始化")
            os_log("\(self.t) 自动批准风险设置：\(self.autoApproveRisk)")
        }
    }

    // MARK: - 项目选择提示

    private func showProjectSelectionPrompt() {
        Task {
            let prompt = await promptService.getWelcomeMessage()
            messages.append(ChatMessage(role: .assistant, content: prompt))
        }
    }

    // MARK: - 消息发送

    func sendMessage() {
        guard !currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !pendingAttachments.isEmpty else { return }

        if Self.verbose {
            os_log("\(self.t) 用户发送消息")
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

        // 处理附件 - 转换为结构化图片数据
        var images: [ImageAttachment] = []
        if !pendingAttachments.isEmpty {
            if Self.verbose {
                os_log("\(self.t)📎 处理 \(self.pendingAttachments.count) 个附件")
            }
            for attachment in pendingAttachments {
                if case .image(_, let data, let mimeType, _) = attachment {
                    images.append(ImageAttachment(data: data, mimeType: mimeType))
                    if Self.verbose {
                        os_log("\(self.t) - 图片：\(mimeType), 大小：\(data.count) bytes")
                    }
                }
            }
            pendingAttachments.removeAll()
        } else if Self.verbose {
            os_log("\(self.t)📎 无附件")
        }

        let userMsg = ChatMessage(role: .user, content: finalContent, images: images)

        if Self.verbose && !images.isEmpty {
            os_log("\(self.t)✅ 用户消息包含 \(images.count) 张图片")
        }

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
        // 使用 ToolManager 查找工具
        guard toolManager.hasTool(named: request.toolName) else {
            messages.append(ChatMessage(
                role: .user,
                content: "Error: Tool '\(request.toolName)' not found.",
                toolCallID: request.toolCallID
            ))
            await processPendingTools()
            return
        }

        do {
            // 使用 ToolManager 执行工具
            let result = try await toolManager.executeTool(
                named: request.toolName,
                arguments: request.arguments
            )

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
                os_log("\(self.t) 继续处理下一个工具：\(nextTool.name)")
            }
            await handleToolCall(nextTool)
        } else {
            if Self.verbose {
                os_log("\(self.t) 所有工具处理完成，继续对话")
            }
            await processTurn(depth: currentDepth + 1)
        }
    }

    private func handleToolCall(_ toolCall: ToolCall) async {
        if Self.verbose {
            os_log("\(self.t)⚙️ 正在执行工具：\(toolCall.name)")
        }

        // 检查权限
        // 如果开启了自动批准，或者工具不需要权限
        let requiresPermission = PermissionService.shared.requiresPermission(toolName: toolCall.name, arguments: parseArguments(toolCall.arguments))

        if requiresPermission && !autoApproveRisk {
            if Self.verbose {
                os_log("\(self.t)⚠️ 工具 \(toolCall.name) 需要权限批准")
            }
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

        // 解析参数（确保 Sendable）
        let arguments: [String: AnySendable]
        if let data = toolCall.arguments.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // 转换为 AnySendable 以确保线程安全
            arguments = json.mapValues { AnySendable(value: $0) }
        } else {
            arguments = [:]
        }

        // 使用 ToolManager 查找工具
        guard toolManager.hasTool(named: toolCall.name) else {
            os_log(.error, "\(self.t)❌ 工具 '\(toolCall.name)' 未找到")
            messages.append(ChatMessage(
                role: .user,
                content: "Error: Tool '\(toolCall.name)' not found.",
                toolCallID: toolCall.id
            ))
            await processPendingTools()
            return
        }

        do {
            let startTime = Date()

            // 在 async 调用前准备好参数
            // 将 arguments 数据复制到局部变量，避免在 async 上下文中捕获
            let toolArguments: [String: Any] = arguments.mapValues { $0.value }

            // 抑制数据竞争警告：toolArguments 是值类型，在 await 传递时已经完成复制
            // 这是安全的，因为 dictionary 在传递时被完整复制
            nonisolated(unsafe) let unsafeArgs = toolArguments

            // 使用 ToolManager 执行工具
            let result = try await toolManager.executeTool(
                named: toolCall.name,
                arguments: unsafeArgs
            )

            let duration = Date().timeIntervalSince(startTime)

            messages.append(ChatMessage(
                role: .user,
                content: result,
                toolCallID: toolCall.id
            ))

            await processPendingTools()
        } catch {
            os_log(.error, "\(self.t)❌ 工具执行失败：\(error.localizedDescription)")
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
        let maxDepth = 100

        guard depth < maxDepth else {
            errorMessage = "Max recursion depth reached."
            isProcessing = false
            depthWarning = DepthWarning(currentDepth: depth, maxDepth: maxDepth, warningType: .reached)
            os_log(.error, "\(self.t) 达到最大递归深度 (\(maxDepth))，对话终止")
            return
        }

        currentDepth = depth
        if Self.verbose {
            os_log("\(self.t) 开始处理对话轮次 (深度：\(depth), 模式：\(self.chatMode.displayName))")
        }

        // 更新深度警告状态
        updateDepthWarning(currentDepth: depth, maxDepth: maxDepth)

        // 根据聊天模式决定是否传递工具
        let availableTools: [AgentTool] = (chatMode == .build) ? tools : []

        if Self.verbose && chatMode == .chat {
            os_log("\(self.t) 当前为对话模式，不传递工具")
        }

        do {
            let config = getCurrentConfig()

            if Self.verbose {
                os_log("\(self.t) 调用 LLM (供应商：\(config.providerId), 模型：\(config.model))")
            }

            // 1. 获取 LLM 响应
            let responseMsg = try await llmService.sendMessage(messages: messages, config: config, tools: availableTools)
            messages.append(responseMsg)

            // 2. 检查工具调用
            if let toolCalls = responseMsg.toolCalls, !toolCalls.isEmpty {
                if Self.verbose {
                    os_log("\(self.t)🔧 收到 \(toolCalls.count) 个工具调用，开始执行:")
                    for (index, tc) in toolCalls.enumerated() {
                        // 格式化参数显示（限制长度）
                        var argsPreview = tc.arguments
                        if argsPreview.count > 100 {
                            argsPreview = String(argsPreview.prefix(100)) + "..."
                        }
                        os_log("\(self.t)  \(index + 1). \(tc.name)(\(argsPreview))")
                    }
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
            os_log(.error, "\(self.t) 对话处理失败：\(error.localizedDescription)")
        }
    }

    // MARK: - 深度警告管理

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
            os_log("\(self.t) 更新模型：\(providerType.displayName) -> \(model)")
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
            os_log("\(self.t) 保存模型到项目配置：\(self.currentProjectName) -> \(self.currentModel)")
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
            os_log("\(self.t) 已设置 \(providerType.displayName) 的 API Key")
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
        let languagePreference = self.languagePreference
        let isProjectSelected = self.isProjectSelected

        Task {
            let fullSystemPrompt = await promptService.buildSystemPrompt(
                languagePreference: languagePreference,
                includeContext: isProjectSelected
            )
            messages = [ChatMessage(role: .system, content: fullSystemPrompt)]
        }
    }

    /// 开启新会话 - 清除历史并显示欢迎消息
    func startNewChat() {
        let languagePreference = self.languagePreference
        let isProjectSelected = self.isProjectSelected
        let currentProjectName = self.currentProjectName
        let currentProjectPath = self.currentProjectPath

        withAnimation {
            // 清除深度警告和错误
            depthWarning = nil
            errorMessage = nil
            isProcessing = false
            currentInput = ""
            pendingAttachments.removeAll()
        }

        Task { @MainActor in
            // 重新构建系统提示
            let fullSystemPrompt = await promptService.buildSystemPrompt(
                languagePreference: languagePreference,
                includeContext: isProjectSelected
            )
            messages = [ChatMessage(role: .system, content: fullSystemPrompt)]

            // 显示欢迎消息
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

            if Self.verbose {
                os_log("\(self.t)✅ 已开启新会话")
            }
        }
    }

    // MARK: - 语言偏好管理

    /// 通知语言切换
    private func notifyLanguageChange() {
        let languagePreference = self.languagePreference
        let isProjectSelected = self.isProjectSelected

        Task { @MainActor in
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

    /// 通知模式切换到对话模式
    private func notifyModeChangeToChat() async {
        let message: String
        switch languagePreference {
        case .chinese:
            message = "已切换到对话模式。在此模式下，我将只与您进行对话，不会执行任何工具或修改代码。有什么问题我可以帮您解答？"
        case .english:
            message = "Switched to Chat mode. In this mode, I will only chat with you without executing any tools or modifying code. How can I help you today?"
        }

        messages.append(ChatMessage(role: .assistant, content: message))
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
