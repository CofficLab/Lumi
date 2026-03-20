import Foundation
import MagicKit
import OSLog

/// 发送消息。
///
/// ## 职责
/// 负责消息发送的队列调度，并启动 `MessageSendPipeline`：
/// 1. 从队列取出待发送消息
/// 2. 跑发送管线（包含 SlashCommandMiddleware + 插件 middleware + CoreSendMiddleware）
/// 3. 从队列移除已完成的消息
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
            await sendCoreMessage(
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
        slashCommandService: SlashCommandService,
        enqueueTurnProcessing: @escaping (UUID, Int) -> Void
    ) async {
        let services = makeMiddlewareServices(
            conversationVM: conversationVM,
            messageViewModel: messageViewModel,
            slashCommandService: slashCommandService,
            sessionConfig: sessionConfig,
            projectVM: projectVM,
            enqueueTurnProcessing: enqueueTurnProcessing
        )
        let ctx = MessageSendMiddlewareContext(runtimeStore: runtimeStore, services: services)

        let pluginRows = PluginVM.shared.getMessageSendMiddlewares()

        let slashMiddleware = AnyMessageSendMiddleware(SlashCommandMiddleware())
        let coreSendMiddleware = AnyMessageSendMiddleware(CoreSendMiddleware())
        let all = [slashMiddleware] + pluginRows + [coreSendMiddleware]

        let pipeline = MessageSendPipeline(
            middlewares: all.map { m in
                { event, c, next in
                    await m.handle(event: event, ctx: c, next: next)
                }
            }
        )

        await pipeline.run(.sendMessage(message, conversationId: conversationId), ctx: ctx) { _, _ in
            // no-op: core send 由 `CoreSendMiddleware` 短路执行
        }
    }

    @MainActor
    private static func makeMiddlewareServices(
        conversationVM: ConversationVM,
        messageViewModel: MessagePendingVM,
        slashCommandService: SlashCommandService,
        sessionConfig: AgentSessionConfig,
        projectVM: ProjectVM,
        enqueueTurnProcessing: @escaping (UUID, Int) -> Void
    ) -> MessageSendMiddlewareServices {
        MessageSendMiddlewareServices(
            isSlashCommand: { input in
                await slashCommandService.isSlashCommand(input)
            },
            handleSlashCommand: { input in
                await slashCommandService.handle(input: input)
            },
            getSelectedConversationId: { conversationVM.selectedConversationId },
            appendMessage: { message in
                messageViewModel.appendMessage(message)
            },
            saveMessage: { message, conversationId in
                await conversationVM.saveMessage(message, to: conversationId)
            },
            enqueueTurnProcessing: enqueueTurnProcessing,
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
