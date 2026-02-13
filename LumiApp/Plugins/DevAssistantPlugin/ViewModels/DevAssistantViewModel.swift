import Combine
import Foundation
import SwiftUI

@MainActor
class DevAssistantViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var currentInput: String = ""
    @Published var isProcessing: Bool = false
    @Published var errorMessage: String?

    // Permission Handling
    @Published var pendingPermissionRequest: PermissionRequest?
    private var pendingToolCalls: [ToolCall] = [] // Queue for remaining tools if we handle one by one
    private var currentDepth: Int = 0

    // Project Info
    @Published var currentProjectName: String = ""
    @Published var currentProjectPath: String = ""

    // Config
    @AppStorage("DevAssistant_SelectedProvider") var selectedProvider: LLMProvider = .anthropic

    // Anthropic
    @AppStorage("DevAssistant_ApiKey_Anthropic") var apiKeyAnthropic: String = ""

    // OpenAI
    @AppStorage("DevAssistant_ApiKey_OpenAI") var apiKeyOpenAI: String = ""

    // DeepSeek
    @AppStorage("DevAssistant_ApiKey_DeepSeek") var apiKeyDeepSeek: String = ""

    // Zhipu AI
    @AppStorage("DevAssistant_ApiKey_Zhipu") var apiKeyZhipu: String = ""

    private let llmService = LLMService.shared

    // Tools
    private let tools: [AgentTool]

    // System Prompt
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

    init() {
        // Initialize Tools
        self.tools = [
            ListDirectoryTool(),
            ReadFileTool(),
            WriteFileTool(),
            ShellTool(shellService: .shared),
        ]

        // Initialize Context and History
        Task {
            // Try to set project root to common location for development
            // In production, this should be passed from the host app
            let rootURL = URL(fileURLWithPath: "/Users/colorfy/Code/CofficLab/Lumi")
            await ContextService.shared.setProjectRoot(rootURL)
            
            self.currentProjectName = rootURL.lastPathComponent
            self.currentProjectPath = rootURL.path

            let context = await ContextService.shared.getContextPrompt()
            let fullSystemPrompt = systemPrompt + "\n\n" + context

            messages.append(ChatMessage(role: .system, content: fullSystemPrompt))
            messages.append(ChatMessage(role: .assistant, content: "Hello! I am your Dev Assistant. How can I help you today?"))
        }
    }

    func sendMessage() {
        guard !currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let input = currentInput
        currentInput = ""
        isProcessing = true
        errorMessage = nil

        // Check for Slash Command
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
                    // Fallback to normal chat if not handled (shouldn't happen with hasPrefix check unless logic changes)
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

    // MARK: - API for SlashCommandService

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

        // We simulate a user asking for a plan with this specific prompt
        Task {
            await processUserMessage(planPrompt)
        }
    }

    // MARK: - Permission Handling

    func respondToPermissionRequest(allowed: Bool) {
        guard let request = pendingPermissionRequest else { return }

        pendingPermissionRequest = nil

        Task {
            if allowed {
                // Execute the tool
                await executePendingTool(request: request)
            } else {
                // Deny execution
                messages.append(ChatMessage(
                    role: .user,
                    content: "Tool execution denied by user.",
                    toolCallID: request.toolCallID
                ))

                // Continue with remaining tools or next turn
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
            let nextToolCall = pendingToolCalls.removeFirst()
            await handleToolCall(nextToolCall)
        } else {
            // All tools in this batch handled, continue recursion
            await processTurn(depth: currentDepth + 1)
        }
    }

    private func handleToolCall(_ toolCall: ToolCall) async {
        // Check Permission
        if PermissionService.shared.requiresPermission(toolName: toolCall.name) {
            pendingPermissionRequest = PermissionRequest(
                toolName: toolCall.name,
                argumentsString: toolCall.arguments,
                toolCallID: toolCall.id
            )
            // Wait for user interaction (via UI binding to pendingPermissionRequest)
            return
        }

        // Parse arguments
        var arguments: [String: Any] = [:]
        if let data = toolCall.arguments.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            arguments = json
        }

        // Execute directly if no permission needed
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

    private func processTurn(depth: Int = 0) async {
        guard depth < 10 else {
            errorMessage = "Max recursion depth reached."
            isProcessing = false
            return
        }

        self.currentDepth = depth

        do {
            let config = getCurrentConfig()

            // 1. Get LLM Response
            let responseMsg = try await llmService.sendMessage(messages: messages, config: config, tools: tools)
            messages.append(responseMsg)

            // 2. Check for Tool Calls
            if let toolCalls = responseMsg.toolCalls, !toolCalls.isEmpty {
                self.pendingToolCalls = toolCalls

                // Start processing the first tool
                let firstTool = self.pendingToolCalls.removeFirst()
                await handleToolCall(firstTool)

            } else {
                // No tool calls, turn finished
                isProcessing = false
            }

        } catch {
            errorMessage = error.localizedDescription
            messages.append(ChatMessage(role: .assistant, content: "Error: \(error.localizedDescription)", isError: true))
            isProcessing = false
        }
    }

    func clearHistory() {
        Task {
            let context = await ContextService.shared.getContextPrompt()
            let fullSystemPrompt = systemPrompt + "\n\n" + context
            messages = [ChatMessage(role: .system, content: fullSystemPrompt)]
        }
    }

    private func getCurrentConfig() -> LLMConfig {
        switch selectedProvider {
        case .anthropic:
            return LLMConfig(apiKey: apiKeyAnthropic, model: selectedProvider.defaultModel, provider: .anthropic)
        case .openai:
            return LLMConfig(apiKey: apiKeyOpenAI, model: selectedProvider.defaultModel, provider: .openai)
        case .deepseek:
            return LLMConfig(apiKey: apiKeyDeepSeek, model: selectedProvider.defaultModel, provider: .deepseek)
        case .zhipu:
            return LLMConfig(apiKey: apiKeyZhipu, model: selectedProvider.defaultModel, provider: .zhipu)
        }
    }

    // Helpers for View Binding
    var currentModel: String {
        return selectedProvider.defaultModel
    }
}

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .withNavigation(DevAssistantPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
