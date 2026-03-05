import Foundation
import MagicKit
import OSLog
import SwiftUI

/// 对话轮次处理 ViewModel
/// 负责处理对话轮次、工具调用和权限管理
///
/// 此类不再标记 @MainActor，所有耗时操作在后台执行
/// 委托回调会自动回到主线程（因为协议标记了 @MainActor）
final class ConversationTurnViewModel: ObservableObject, SuperLog {
    nonisolated static let emoji = "🔄"
    nonisolated static let verbose = true

    // MARK: - 服务依赖

    /// LLM 服务
    private let llmService: LLMService

    /// 工具管理器
    private let toolManager: ToolManager

    /// 提示词服务
    private let promptService: PromptService

    /// 后台任务调度器
    private let jobScheduler: JobScheduler

    // MARK: - 回调委托

    /// 对话轮次处理委托
    weak var delegate: ConversationTurnDelegate?

    // MARK: - 处理状态

    /// 当前递归深度
    private var currentDepth: Int = 0

    /// 待处理工具调用队列
    private var pendingToolCalls: [ToolCall] = []

    /// 最大递归深度
    private let maxDepth = 100

    // MARK: - 初始化

    init(
        llmService: LLMService,
        toolManager: ToolManager,
        promptService: PromptService,
        jobScheduler: JobScheduler = .shared
    ) {
        self.llmService = llmService
        self.toolManager = toolManager
        self.promptService = promptService
        self.jobScheduler = jobScheduler
    }

    // MARK: - 对话轮次处理

    /// 处理对话轮次
    ///
    /// 此方法不再标记 @MainActor，整个方法在后台执行
    /// 委托回调会自动回到主线程
    ///
    /// - Parameters:
    ///   - depth: 当前递归深度
    ///   - config: LLM 配置
    ///   - messages: 当前消息列表
    ///   - chatMode: 聊天模式
    ///   - tools: 可用工具列表
    ///   - languagePreference: 语言偏好
    ///   - autoApproveRisk: 是否自动批准风险操作
    func processTurn(
        depth: Int = 0,
        config: LLMConfig,
        messages: [ChatMessage],
        chatMode: ChatMode,
        tools: [AgentTool],
        languagePreference: LanguagePreference,
        autoApproveRisk: Bool
    ) async {
        guard depth < maxDepth else {
            await delegate?.turnDidReachMaxDepth(currentDepth: depth, maxDepth: maxDepth)
            return
        }

        currentDepth = depth
        if Self.verbose {
            os_log("\(Self.t) 开始处理对话轮次 (深度：\(depth), 模式：\(chatMode.displayName))")
        }

        // 更新深度警告状态
        updateDepthWarning(currentDepth: depth, maxDepth: maxDepth)

        // 根据聊天模式决定是否传递工具
        let availableTools: [AgentTool] = (chatMode == .build) ? tools : []

        if Self.verbose && chatMode == .chat {
            os_log("\(Self.t) 当前为对话模式，不传递工具")
        }

        do {
            if Self.verbose {
                os_log("\(Self.t)🌍 开始调用 LLM (供应商：\(config.providerId), 模型：\(config.model))")
            }

            // 1. 获取 LLM 响应（在后台执行）
            var responseMsg = try await jobScheduler.executeLLMRequest(
                messages: messages,
                config: config,
                tools: availableTools,
                registry: ProviderRegistry.shared
            )

            // 检查内容是否为空（只有空白字符）
            let hasContent = !responseMsg.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let hasToolCalls = responseMsg.toolCalls != nil && !responseMsg.toolCalls!.isEmpty

            // 当无内容但有工具调用时，生成一个友好的提示消息
            if !hasContent && hasToolCalls {
                // 生成工具调用摘要
                let toolSummary = responseMsg.toolCalls!.enumerated().map { index, tc in
                    let emoji = toolEmoji(for: tc.name)
                    return "\(emoji) \(tc.name)"
                }.joined(separator: "\n")

                let prefix = languagePreference == .chinese
                    ? "正在执行 \(responseMsg.toolCalls!.count) 个工具："
                    : "Executing \(responseMsg.toolCalls!.count) tools:"

                let enhancedContent = prefix + "\n" + toolSummary
                responseMsg = ChatMessage(
                    role: responseMsg.role,
                    content: enhancedContent,
                    isError: responseMsg.isError,
                    toolCalls: responseMsg.toolCalls,
                    toolCallID: responseMsg.toolCallID
                )

                if Self.verbose {
                    os_log("%{public}@📝 为空内容消息生成工具摘要", Self.t)
                }
            }

            // 立即保存助手消息
            await delegate?.turnDidReceiveResponse(responseMsg)

            // 2. 检查工具调用
            if let toolCalls = responseMsg.toolCalls, !toolCalls.isEmpty {
                if Self.verbose {
                    os_log("\(Self.t)🔧 收到 \(toolCalls.count) 个工具调用，开始执行:")
                    for (index, tc) in toolCalls.enumerated() {
                        os_log("\(Self.t)  \(index + 1). \(tc.name)(\(tc.arguments.max(50)))")
                    }
                }
                pendingToolCalls = toolCalls

                // 开始处理第一个工具
                let firstTool = pendingToolCalls.removeFirst()
                await handleToolCall(
                    firstTool,
                    languagePreference: languagePreference,
                    autoApproveRisk: autoApproveRisk
                )
            } else {
                // 无工具调用，轮次结束
                await delegate?.turnDidComplete()
                if Self.verbose {
                    os_log("\(Self.t)✅ 对话轮次已完成（无工具调用）")
                }
            }
        } catch {
            await delegate?.turnDidEncounterError(error)
            os_log(.error, "\(Self.t) 对话处理失败")
        }
    }

    // MARK: - 工具调用处理

    /// 处理工具调用
    ///
    /// 使用 JobScheduler 进行权限检查和风险评估
    ///
    /// - Parameters:
    ///   - toolCall: 工具调用
    ///   - languagePreference: 语言偏好
    ///   - autoApproveRisk: 是否自动批准风险操作
    private func handleToolCall(
        _ toolCall: ToolCall,
        languagePreference: LanguagePreference,
        autoApproveRisk: Bool
    ) async {
        if Self.verbose {
            os_log("\(Self.t)⚙️ 正在执行工具：\(toolCall.name)")
        }

        // 使用 JobScheduler 检查权限（纯计算，无需后台）
        let requiresPermission = jobScheduler.requiresPermission(toolCall, autoApproveRisk: autoApproveRisk)

        if requiresPermission && !autoApproveRisk {
            if Self.verbose {
                os_log("\(Self.t)⚠️ 工具 \(toolCall.name) 需要权限批准")
            }

            // 评估命令风险（纯计算，无需后台）
            let riskLevel = jobScheduler.evaluateRisk(toolCall)

            // 创建权限请求（纯计算，无需后台）
            let permissionRequest = jobScheduler.createPermissionRequest(toolCall, riskLevel: riskLevel)

            // 请求权限
            await delegate?.turnDidRequestPermission(permissionRequest)
            return
        }

        // 执行工具
        await executeTool(toolCall)
    }

    /// 执行工具调用
    ///
    /// 此方法使用 JobScheduler 在后台执行工具调用
    ///
    /// - Parameter toolCall: 工具调用
    private func executeTool(_ toolCall: ToolCall) async {
        // 使用 ToolManager 查找工具
        guard toolManager.hasTool(named: toolCall.name) else {
            os_log(.error, "\(Self.t)❌ 工具 '\(toolCall.name)' 未找到")
            let errorMsg = ChatMessage(
                role: .user,
                content: "Error: Tool '\(toolCall.name)' not found.",
                toolCallID: toolCall.id
            )
            await delegate?.turnDidReceiveToolResult(errorMsg)
            await processPendingTools(languagePreference: .chinese, autoApproveRisk: false)
            return
        }

        do {
            // 使用 JobScheduler 在后台执行工具
            let (resultMsg, duration) = try await jobScheduler.executeToolCall(
                toolCall: toolCall,
                toolManager: toolManager
            )

            if Self.verbose {
                os_log("\(Self.t)✅ 工具执行完成，耗时：\(String(format: "%.3f", duration))秒")
            }

            await delegate?.turnDidReceiveToolResult(resultMsg)
            await processPendingTools(languagePreference: .chinese, autoApproveRisk: false)
        } catch {
            os_log(.error, "\(Self.t)❌ 工具执行失败：\(error.localizedDescription)")
            let errorMsg = ChatMessage(
                role: .user,
                content: "Error executing tool: \(error.localizedDescription)",
                toolCallID: toolCall.id
            )
            await delegate?.turnDidReceiveToolResult(errorMsg)
            await processPendingTools(languagePreference: .chinese, autoApproveRisk: false)
        }
    }

    /// 处理待处理工具队列
    /// - Parameters:
    ///   - languagePreference: 语言偏好
    ///   - autoApproveRisk: 是否自动批准风险操作
    private func processPendingTools(
        languagePreference: LanguagePreference,
        autoApproveRisk: Bool
    ) async {
        if !pendingToolCalls.isEmpty {
            let nextTool = pendingToolCalls.removeFirst()
            if Self.verbose {
                os_log("\(Self.t) 继续处理下一个工具：\(nextTool.name)")
            }
            await handleToolCall(nextTool, languagePreference: languagePreference, autoApproveRisk: autoApproveRisk)
        } else {
            if Self.verbose {
                os_log("\(Self.t) 所有工具处理完成，继续对话")
            }
            // 通知委托继续下一轮
            await delegate?.turnShouldContinue(depth: currentDepth + 1)
        }
    }

    // MARK: - 权限响应

    /// 响应权限请求
    /// - Parameters:
    ///   - allowed: 是否允许
    ///   - request: 权限请求
    ///   - languagePreference: 语言偏好
    ///   - autoApproveRisk: 是否自动批准风险操作
    func respondToPermissionRequest(
        allowed: Bool,
        request: PermissionRequest,
        languagePreference: LanguagePreference,
        autoApproveRisk: Bool
    ) async {
        if allowed {
            await executePendingTool(request: request, languagePreference: languagePreference, autoApproveRisk: autoApproveRisk)
        } else {
            let deniedMsg = ChatMessage(
                role: .user,
                content: "Tool execution denied by user.",
                toolCallID: request.toolCallID
            )
            await delegate?.turnDidReceiveToolResult(deniedMsg)
            await processPendingTools(languagePreference: languagePreference, autoApproveRisk: autoApproveRisk)
        }
    }

    /// 执行待处理工具（权限已批准）
    /// - Parameters:
    ///   - request: 权限请求
    ///   - languagePreference: 语言偏好
    ///   - autoApproveRisk: 是否自动批准风险操作
    private func executePendingTool(
        request: PermissionRequest,
        languagePreference: LanguagePreference,
        autoApproveRisk: Bool
    ) async {
        // 使用 ToolManager 查找工具
        guard toolManager.hasTool(named: request.toolName) else {
            let errorMsg = ChatMessage(
                role: .user,
                content: "Error: Tool '\(request.toolName)' not found.",
                toolCallID: request.toolCallID
            )
            await delegate?.turnDidReceiveToolResult(errorMsg)
            await processPendingTools(languagePreference: languagePreference, autoApproveRisk: autoApproveRisk)
            return
        }

        do {
            // 使用 ToolManager 执行工具
            let result = try await toolManager.executeTool(
                named: request.toolName,
                arguments: request.arguments
            )

            let resultMsg = ChatMessage(
                role: .user,
                content: result,
                toolCallID: request.toolCallID
            )
            await delegate?.turnDidReceiveToolResult(resultMsg)
            await processPendingTools(languagePreference: languagePreference, autoApproveRisk: autoApproveRisk)
        } catch {
            let errorMsg = ChatMessage(
                role: .user,
                content: "Error executing tool: \(error.localizedDescription)",
                toolCallID: request.toolCallID
            )
            await delegate?.turnDidReceiveToolResult(errorMsg)
            await processPendingTools(languagePreference: languagePreference, autoApproveRisk: autoApproveRisk)
        }
    }

    // MARK: - 深度警告更新

    private func updateDepthWarning(currentDepth: Int, maxDepth: Int) {
        if currentDepth >= maxDepth - 10 {
            delegate?.turnDidUpdateDepthWarning(DepthWarning(
                currentDepth: currentDepth,
                maxDepth: maxDepth,
                warningType: .approaching
            ))
        } else {
            delegate?.turnDidUpdateDepthWarning(nil)
        }
    }

    // MARK: - 工具 Emoji 映射

    /// 获取工具对应的 emoji 图标
    func toolEmoji(for toolName: String) -> String {
        let emojiMap: [String: String] = [
            "read_file": "📖",
            "write_file": "✍️",
            "run_command": "⚡",
            "list_directory": "📁",
            "create_directory": "📂",
            "move_file": "📦",
            "search_files": "🔍",
            "get_file_info": "ℹ️",
            "bash": "⚡",
            "glob": "🔎",
            "edit": "✏️",
            "str_replace_editor": "✏️",
            "lsp": "💻",
            "goto_definition": "➡️",
            "find_references": "🔗",
            "document": "📚",
            "grep": "🔍"
        ]
        return emojiMap[toolName] ?? "🔧"
    }
}

// MARK: - 对话轮次处理委托

/// 对话轮次处理委托协议
@MainActor
protocol ConversationTurnDelegate: AnyObject, Sendable {
    /// 收到 LLM 响应
    func turnDidReceiveResponse(_ response: ChatMessage) async

    /// 对话轮次完成
    func turnDidComplete() async

    /// 遇到错误
    func turnDidEncounterError(_ error: Error) async

    /// 达到最大深度
    func turnDidReachMaxDepth(currentDepth: Int, maxDepth: Int) async

    /// 请求权限
    func turnDidRequestPermission(_ request: PermissionRequest) async

    /// 收到工具执行结果
    func turnDidReceiveToolResult(_ result: ChatMessage) async

    /// 更新深度警告
    func turnDidUpdateDepthWarning(_ warning: DepthWarning?)

    /// 应该继续下一轮
    func turnShouldContinue(depth: Int) async
}
