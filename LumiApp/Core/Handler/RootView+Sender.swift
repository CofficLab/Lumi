import Foundation
import MagicKit
import SwiftUI

// MARK: - RootView 发送队列

extension RootView {
    /// 发送队列调度：取出待发送消息 → 跑 `MessageSendPipeline`（Slash / 插件 / Core）→ 完成后出队。
    @MainActor
    func onSenderPendingMessagesChanged() {
        let vm = container.messageQueueVM
        guard let conversationId = container.conversationVM.selectedConversationId else {
            AppLogger.core.error("\(Self.t) 当前没有选中的会话")
            return
        }
        let pendingMessages = vm.pendingMessages(for: conversationId)
        guard !pendingMessages.isEmpty else { return }
        guard let message = pendingMessages.first else { return }

        vm.setCurrentProcessingIndex(0, for: conversationId)

        if Self.verbose {
            AppLogger.core.info("\(Self.t)📤 [\(String(conversationId.uuidString.prefix(8)))] 开始发送消息：\(message.content.prefix(50))")
        }

        let enqueueTurnProcessing: (UUID, Int) -> Void = { conversationId, depth in
            Task { @MainActor in
                self.enqueueTurnProcessing(conversationId: conversationId, depth: depth)
            }
        }

        Task {
            await Self.sendCoreMessageThroughSendPipeline(
                message: message,
                conversationId: conversationId,
                messageViewModel: container.messageViewModel,
                conversationVM: container.conversationVM,
                runtimeStore: container.conversationRuntimeStore,
                sessionConfig: container.agentSessionConfig,
                projectVM: container.ProjectVM,
                slashCommandService: container.slashCommandService,
                enqueueTurnProcessing: enqueueTurnProcessing
            )

            await MainActor.run {
                vm.removeFirstMessage(for: conversationId)
                vm.setCurrentProcessingIndex(nil, for: conversationId)
                if Self.verbose {
                    AppLogger.core.info("\(Self.t)✅ [\(String(conversationId.uuidString.prefix(8)))] 消息发送完成，已从队列移除")
                }
            }
        }
    }

    /// 核心消息发送：先跑插件 `MessageSendMiddleware` 链，再由链尾执行投影 / 落库 / 入队轮次。
    @MainActor
    private static func sendCoreMessageThroughSendPipeline(
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
        let services = Self.makeMessageSendMiddlewareServices(
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
    private static func makeMessageSendMiddlewareServices(
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
