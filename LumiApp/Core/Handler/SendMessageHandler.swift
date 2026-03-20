import Foundation
import MagicKit
import OSLog

/// 发送消息。
///
/// ## 职责
/// 完全负责消息发送的全部流程，包括：
/// 1. 从队列取出待发送消息
/// 2. Slash 命令处理（如果是命令）
/// 3. 投影到当前消息列表
/// 4. 落库保存消息
/// 5. 触发轮次处理
/// 6. 从队列移除已完成的消息
enum SendMessageHandler: SuperLog {
    nonisolated static let emoji = "📤"
    nonisolated static let verbose = true

    @MainActor
    static func handle(
        vm: MessageQueueVM,
        messageViewModel: MessagePendingVM,
        conversationVM: ConversationVM,
        runtimeStore: ConversationRuntimeStore,
        sessionConfig: AgentSessionConfig,
        projectVM: ProjectVM,
        slashCommandService: SlashCommandService,
        enqueueTurnProcessing: @escaping (UUID, Int) -> Void
    ) {
        guard !vm.pendingMessages.isEmpty else { return }
        guard let conversationId = conversationVM.selectedConversationId else {
            AppLogger.core.error("\(Self.t) 当前没有选中的会话")
            return
        }

        // 从队列头部取出消息并发送
        guard let message = vm.pendingMessages.first else { return }

        // 设置处理中索引
        vm.currentProcessingIndex = 0

        if verbose {
            AppLogger.core.info("\(Self.t)📤 [\(String(conversationId.uuidString.prefix(8)))] 开始发送消息：\(message.content.prefix(50))")
        }

        // 异步发送消息
        Task {
            await sendMessageWithSlashCommandHandling(
                message: message,
                conversationId: conversationId,
                messageViewModel: messageViewModel,
                conversationVM: conversationVM,
                runtimeStore: runtimeStore,
                sessionConfig: sessionConfig,
                projectVM: projectVM,
                slashCommandService: slashCommandService,
                enqueueTurnProcessing: enqueueTurnProcessing
            )

            // 发送完成后从队列中移除
            await MainActor.run {
                vm.pendingMessages.removeFirst()
                vm.currentProcessingIndex = nil
                if verbose {
                    AppLogger.core.info("\(Self.t)✅ [\(String(conversationId.uuidString.prefix(8)))] 消息发送完成，已从队列移除")
                }
            }
        }
    }

    /// 发送消息，包含 Slash 命令处理逻辑
    @MainActor
    private static func sendMessageWithSlashCommandHandling(
        message: ChatMessage,
        conversationId: UUID,
        messageViewModel: MessagePendingVM,
        conversationVM: ConversationVM,
        runtimeStore: ConversationRuntimeStore,
        sessionConfig: AgentSessionConfig,
        projectVM: ProjectVM,
        slashCommandService: SlashCommandService,
        enqueueTurnProcessing: @escaping (UUID, Int) -> Void
    ) async {
        let trimmed = message.content.trimmingCharacters(in: .whitespacesAndNewlines)

        // 检查是否是 Slash 命令
        let isCommand = await slashCommandService.isSlashCommand(trimmed)

        guard isCommand else {
            // 普通消息，直接发送
            await sendCoreMessage(
                message: message,
                conversationId: conversationId,
                messageViewModel: messageViewModel,
                conversationVM: conversationVM,
                runtimeStore: runtimeStore,
                sessionConfig: sessionConfig,
                projectVM: projectVM,
                enqueueTurnProcessing: enqueueTurnProcessing
            )
            return
        }

        // Slash 命令处理 - 使用 handle(input:) 获取结果
        if verbose {
            AppLogger.core.info("\(Self.t) 🔧 检测到 Slash 命令：\(trimmed)")
        }

        let result = await slashCommandService.handle(input: trimmed)
        handleSlashCommandResult(
            result,
            conversationId: conversationId,
            messageViewModel: messageViewModel,
            conversationVM: conversationVM,
            runtimeStore: runtimeStore,
            sessionConfig: sessionConfig,
            projectVM: projectVM,
            originalMessage: message,
            enqueueTurnProcessing: enqueueTurnProcessing
        )
    }

    /// 处理 Slash 命令结果
    @MainActor
    private static func handleSlashCommandResult(
        _ result: SlashCommandResult,
        conversationId: UUID,
        messageViewModel: MessagePendingVM,
        conversationVM: ConversationVM,
        runtimeStore: ConversationRuntimeStore,
        sessionConfig: AgentSessionConfig,
        projectVM: ProjectVM,
        originalMessage: ChatMessage,
        enqueueTurnProcessing: @escaping (UUID, Int) -> Void
    ) {
        switch result {
        case .handled:
            // 命令已处理，无需额外操作
            if verbose {
                AppLogger.core.info("\(Self.t) ✅ Slash 命令已处理")
            }

        case .notHandled:
            // 命令未处理，作为普通消息发送
            if verbose {
                AppLogger.core.info("\(Self.t) ⚠️ Slash 命令未处理，作为普通消息发送")
            }
            Task {
                await sendCoreMessage(
                    message: originalMessage,
                    conversationId: conversationId,
                    messageViewModel: messageViewModel,
                    conversationVM: conversationVM,
                    runtimeStore: runtimeStore,
                    sessionConfig: sessionConfig,
                    projectVM: projectVM,
                    enqueueTurnProcessing: enqueueTurnProcessing
                )
            }

        case let .error(msg):
            // 执行出错，添加错误消息
            if verbose {
                AppLogger.core.info("\(Self.t) ❌ Slash 命令执行出错：\(msg)")
            }
            let errorMessage = ChatMessage(role: .assistant, content: "命令错误：\(msg)", isError: true)
            messageViewModel.appendMessage(errorMessage)

        case let .systemMessage(content):
            // 系统消息
            if verbose {
                AppLogger.core.info("\(Self.t) 📋 添加系统消息")
            }
            let systemMessage = ChatMessage(role: .assistant, content: content)
            messageViewModel.appendMessage(systemMessage)

        case let .userMessage(content, triggerProcessing):
            // 用户消息并触发处理
            if verbose {
                AppLogger.core.info("\(Self.t) 📝 添加用户消息并触发处理：\(triggerProcessing)")
            }
            let userMessage = ChatMessage(role: .user, content: content)
            messageViewModel.appendMessage(userMessage)
            Task {
                await conversationVM.saveMessage(userMessage, to: conversationId)
                if triggerProcessing {
                    enqueueTurnProcessing(conversationId, 0)
                }
            }

        case .clearHistory:
            // 清空历史记录
            if verbose {
                AppLogger.core.info("\(Self.t) 🗑️ 清空历史记录")
            }

        case let .triggerPlanning(task):
            // 触发规划模式
            if verbose {
                AppLogger.core.info("\(Self.t) 📋 触发规划模式：\(task)")
            }

        case let .mcpCommand(subCommand, param):
            // MCP 命令
            if verbose {
                AppLogger.core.info("\(Self.t) 🔧 MCP 命令：\(subCommand) \(param)")
            }
        }
    }

    /// 核心消息发送：先跑插件 `MessageSendMiddleware` 链，再由链尾执行投影 / 落库 / 入队轮次。
    @MainActor
    private static func sendCoreMessage(
        message: ChatMessage,
        conversationId: UUID,
        messageViewModel: MessagePendingVM,
        conversationVM: ConversationVM,
        runtimeStore: ConversationRuntimeStore,
        sessionConfig: AgentSessionConfig,
        projectVM: ProjectVM,
        enqueueTurnProcessing: @escaping (UUID, Int) -> Void
    ) async {
        if verbose {
            AppLogger.core.info("\(Self.t)📨 [\(String(conversationId.uuidString.prefix(8)))] 发送核心消息：\(message.content.prefix(50))")
        }

        let services = makeMiddlewareServices(
            conversationVM: conversationVM,
            sessionConfig: sessionConfig,
            projectVM: projectVM
        )
        let ctx = MessageSendMiddlewareContext(runtimeStore: runtimeStore, services: services)

        let pluginRows = PluginVM.shared.getMessageSendMiddlewares()
        let pipeline = MessageSendPipeline(
            middlewares: pluginRows.map { m in
                { event, c, next in
                    await m.handle(event: event, ctx: c, next: next)
                }
            }
        )

        await pipeline.run(.sendMessage(message, conversationId: conversationId), ctx: ctx) { event, _ in
            guard case let .sendMessage(msg, cid) = event else { return }
            await performCoreSend(
                message: msg,
                conversationId: cid,
                messageViewModel: messageViewModel,
                conversationVM: conversationVM,
                enqueueTurnProcessing: enqueueTurnProcessing
            )
        }
    }

    @MainActor
    private static func performCoreSend(
        message: ChatMessage,
        conversationId: UUID,
        messageViewModel: MessagePendingVM,
        conversationVM: ConversationVM,
        enqueueTurnProcessing: @escaping (UUID, Int) -> Void
    ) async {
        // 1) 投影到当前消息列表（仅当该会话仍处于选中状态）
        if conversationVM.selectedConversationId == conversationId {
            messageViewModel.appendMessage(message)
        }

        // 2) 落库保存
        await conversationVM.saveMessage(message, to: conversationId)

        // 3) 触发轮次处理（深度从 0 开始）
        enqueueTurnProcessing(conversationId, 0)
    }

    @MainActor
    private static func makeMiddlewareServices(
        conversationVM: ConversationVM,
        sessionConfig: AgentSessionConfig,
        projectVM: ProjectVM
    ) -> MessageSendMiddlewareServices {
        MessageSendMiddlewareServices(
            getConversationTitle: { id in conversationVM.fetchConversation(id: id)?.title },
            getCurrentConfig: { sessionConfig.getCurrentConfig() },
            generateConversationTitle: { userMessage, config in
                await conversationVM.generateConversationTitle(from: userMessage, config: config)
            },
            updateConversationTitleIfUnchanged: { conversationId, expectedTitle, newTitle in
                await MainActor.run {
                    guard let conv = conversationVM.fetchConversation(id: conversationId) else { return false }
                    guard conv.title == expectedTitle else { return false }
                    conversationVM.updateConversationTitle(conv, newTitle: newTitle)
                    return true
                }
            },
            isProjectSelected: { projectVM.isProjectSelected },
            getProjectInfo: { (projectVM.currentProjectName, projectVM.currentProjectPath) },
            isFileSelected: { projectVM.selectedFileURL != nil || !projectVM.selectedFilePath.isEmpty },
            getSelectedFileInfo: { (projectVM.selectedFilePath, projectVM.selectedFileContent) },
            getSelectedText: { TextSelectionManager.shared.selectedText },
            getMessageCount: { id in
                guard let conv = conversationVM.fetchConversation(id: id) else { return 0 }
                return conv.messages
                    .compactMap { $0.toChatMessage() }
                    .filter { $0.shouldDisplayInChatList() }
                    .count
            }
        )
    }
}
