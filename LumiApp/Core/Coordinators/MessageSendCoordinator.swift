import Foundation

/// 消息发送事件协调器
///
/// 负责消费 `MessageSenderViewModel.events`，并把事件翻译为对各个状态/服务的调用。
@MainActor
final class MessageSendCoordinator {
    private let messageSenderViewModel: MessageSenderViewModel
    private let runtimeStore: ConversationRuntimeStore

    private let onUserJustSentMessage: () -> Void
    private let onProcessingStarted: (UUID) -> Void
    private let onProcessingFinished: (UUID) -> Void
    private let sendMessageToAgent: (ChatMessage, UUID) async -> Void

    private var task: Task<Void, Never>?
    private var pipeline: MiddlewarePipeline<MessageSendEvent, MessageSendMiddlewareContext>?

    init(
        messageSenderViewModel: MessageSenderViewModel,
        runtimeStore: ConversationRuntimeStore,
        onUserJustSentMessage: @escaping () -> Void,
        onProcessingStarted: @escaping (UUID) -> Void,
        onProcessingFinished: @escaping (UUID) -> Void,
        sendMessageToAgent: @escaping (ChatMessage, UUID) async -> Void
    ) {
        self.messageSenderViewModel = messageSenderViewModel
        self.runtimeStore = runtimeStore
        self.onUserJustSentMessage = onUserJustSentMessage
        self.onProcessingStarted = onProcessingStarted
        self.onProcessingFinished = onProcessingFinished
        self.sendMessageToAgent = sendMessageToAgent
    }

    func start() {
        task?.cancel()

        let pluginMiddlewares = PluginProvider.shared.getMessageSendMiddlewares()
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
            for await event in self.messageSenderViewModel.events {
                let ctx = MessageSendMiddlewareContext(runtimeStore: self.runtimeStore)
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

