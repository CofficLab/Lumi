import Foundation

/// 消息发送事件协调器
///
/// 负责消费 `MessageSenderVM.events`，并把事件翻译为对各个状态/服务的调用。
@MainActor
final class MessageSendCoordinator {
    struct Services {
        let getConversationTitle: (UUID) -> String?
        let getCurrentConfig: () -> LLMConfig
        let generateConversationTitle: @Sendable (String, LLMConfig) async -> String
        let updateConversationTitleIfUnchanged: @Sendable (UUID, String, String) async -> Bool

        let isProjectSelected: () -> Bool
        let getProjectInfo: () -> (name: String, path: String)
        let isFileSelected: () -> Bool
        let getSelectedFileInfo: () -> (path: String, content: String)
        let getSelectedText: () -> String?
        let getMessageCount: (UUID) -> Int
    }

    private let MessageSenderVM: MessageSenderVM
    private let runtimeStore: ConversationRuntimeStore
    private let services: Services

    private let onUserJustSentMessage: () -> Void
    private let onProcessingStarted: (UUID) -> Void
    private let onProcessingFinished: (UUID) -> Void
    private let sendMessageToAgent: (ChatMessage, UUID) async -> Void

    private var task: Task<Void, Never>?
    private var pipeline: MiddlewarePipeline<MessageSendEvent, MessageSendMiddlewareContext>?

    init(
        MessageSenderVM: MessageSenderVM,
        runtimeStore: ConversationRuntimeStore,
        services: Services,
        onUserJustSentMessage: @escaping () -> Void,
        onProcessingStarted: @escaping (UUID) -> Void,
        onProcessingFinished: @escaping (UUID) -> Void,
        sendMessageToAgent: @escaping (ChatMessage, UUID) async -> Void
    ) {
        self.MessageSenderVM = MessageSenderVM
        self.runtimeStore = runtimeStore
        self.services = services
        self.onUserJustSentMessage = onUserJustSentMessage
        self.onProcessingStarted = onProcessingStarted
        self.onProcessingFinished = onProcessingFinished
        self.sendMessageToAgent = sendMessageToAgent
    }

    func start() {
        task?.cancel()

        let pluginMiddlewares = PluginVM.shared.getMessageSendMiddlewares()
            .sorted { a, b in
                if a.order != b.order { return a.order < b.order }
                return a.id < b.id
            }

        pipeline = MiddlewarePipeline<MessageSendEvent, MessageSendMiddlewareContext>(
            middlewares: pluginMiddlewares.map { m in
                { event, ctx, next in
                    await m.handle(event: event, ctx: ctx, next: next)
                }
            }
        )

        task = Task { [weak self] in
            guard let self else { return }
            for await event in self.MessageSenderVM.events {
                let ctx = MessageSendMiddlewareContext(
                    runtimeStore: self.runtimeStore,
                    services: MessageSendMiddlewareServices(
                        getConversationTitle: self.services.getConversationTitle,
                        getCurrentConfig: self.services.getCurrentConfig,
                        generateConversationTitle: self.services.generateConversationTitle,
                        updateConversationTitleIfUnchanged: self.services.updateConversationTitleIfUnchanged,
                        isProjectSelected: self.services.isProjectSelected,
                        getProjectInfo: self.services.getProjectInfo,
                        isFileSelected: self.services.isFileSelected,
                        getSelectedFileInfo: self.services.getSelectedFileInfo,
                        getSelectedText: self.services.getSelectedText,
                        getMessageCount: self.services.getMessageCount
                    )
                )
                if let pipeline = self.pipeline {
                    await pipeline.run(event, ctx: ctx) { event, _ in
                        await self.handle(event)
                    }
                } else {
                    await self.handle(event)
                }
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func handle(_ event: MessageSendEvent) async {
        switch event {
        case let .processingStarted(conversationId):
            runtimeStore.processingConversationIds.insert(conversationId)
            onProcessingStarted(conversationId)
            runtimeStore.updateRuntimeState(for: conversationId)

        case let .processingFinished(conversationId):
            runtimeStore.processingConversationIds.remove(conversationId)
            onProcessingFinished(conversationId)
            runtimeStore.updateRuntimeState(for: conversationId)

        case let .sendMessage(message, conversationId):
            onUserJustSentMessage()
            await sendMessageToAgent(message, conversationId)
        }
    }
}

