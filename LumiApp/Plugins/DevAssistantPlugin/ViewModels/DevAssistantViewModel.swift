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

    // MARK: - 系统提示

    private let systemPrompt = """
    You are an expert software engineer and agentic coding tool (DevAssistant).
    You have access to a set of tools to explore the codebase, read files, and execute commands.

    Your goal is to help the user complete tasks efficiently.
    1. Always analyze the request first.
    2. Use tools to gather information (ls, read_file).
    3. Formulate a plan if the task is complex.
    4. Execute the plan using tools.

    The user is on macOS.
    """

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

        // 初始化上下文和历史
        Task {
            // 设置项目根目录
            let rootURL = URL(fileURLWithPath: "/Users/colorfy/Code/CofficLab/Lumi")
            await ContextService.shared.setProjectRoot(rootURL)

            self.currentProjectName = rootURL.lastPathComponent
            self.currentProjectPath = rootURL.path

            let context = await ContextService.shared.getContextPrompt()
            let fullSystemPrompt = systemPrompt + "\n\n" + context

            messages.append(ChatMessage(role: .system, content: fullSystemPrompt))
            messages.append(ChatMessage(role: .assistant, content: "Hello! I am your Dev Assistant. How can I help you today?"))
        }

        if Self.verbose {
            os_log("\(self.t)DevAssistant 视图模型已初始化")
        }
    }

    // MARK: - 消息发送

    func sendMessage() {
        guard !currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

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
        if PermissionService.shared.requiresPermission(toolName: toolCall.name) {
            pendingPermissionRequest = PermissionRequest(
                toolName: toolCall.name,
                argumentsString: toolCall.arguments,
                toolCallID: toolCall.id
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
        let planPrompt = """
        ACT AS: Architect / Planner
        TASK: \(task)

        Please generate a detailed implementation plan in Markdown.
        Structure:
        1. Analysis
        2. Implementation Steps
        3. Verification

        Do not write code yet, just the plan.
        """

        Task {
            await processUserMessage(planPrompt)
        }
    }

    // MARK: - 历史记录管理

    func clearHistory() {
        Task {
            let context = await ContextService.shared.getContextPrompt()
            let fullSystemPrompt = systemPrompt + "\n\n" + context
            messages = [ChatMessage(role: .system, content: fullSystemPrompt)]
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
