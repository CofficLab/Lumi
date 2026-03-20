import Foundation

/// 消息发送事件协调器
///
/// 负责消费 `MessageSenderVM.events`，并把事件翻译为对各个状态/服务的调用。
@MainActor
final class MessageSendCoordinator {
    private let messageSenderViewModel: MessageSenderVM
    private let runtimeStore: ConversationRuntimeStore
    private let services: MessageSendMiddlewareServices

    private let onProcessingStarted: (UUID) -> Void
    private let onProcessingFinished: (UUID) -> Void
    private let sendMessageToAgent: (ChatMessage, UUID) async -> Void

    private var task: Task<Void, Never>?
    private var pipeline: MiddlewarePipeline<MessageSendEvent, MessageSendMiddlewareContext>?
    private var pluginsDidLoadObserver: NSObjectProtocol?

    init(
        messageSenderViewModel: MessageSenderVM,
        runtimeStore: ConversationRuntimeStore,
        services: MessageSendMiddlewareServices,
        onProcessingStarted: @escaping (UUID) -> Void,
        onProcessingFinished: @escaping (UUID) -> Void,
        sendMessageToAgent: @escaping (ChatMessage, UUID) async -> Void
    ) {
        self.messageSenderViewModel = messageSenderViewModel
        self.runtimeStore = runtimeStore
        self.services = services
        self.onProcessingStarted = onProcessingStarted
        self.onProcessingFinished = onProcessingFinished
        self.sendMessageToAgent = sendMessageToAgent
    }

    func start() {
        task?.cancel()

        if pluginsDidLoadObserver == nil {
            pluginsDidLoadObserver = NotificationCenter.default.addObserver(
                forName: .pluginsDidLoad,
                object: nil,
                queue: nil
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.rebuildPipeline()
                }
            }
        }

        rebuildPipeline()

        task = Task { [weak self] in
            guard let self else { return }
            for await event in self.messageSenderViewModel.events {
                let ctx = MessageSendMiddlewareContext(
                    runtimeStore: self.runtimeStore,
                    services: self.services
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

        if let pluginsDidLoadObserver {
            NotificationCenter.default.removeObserver(pluginsDidLoadObserver)
            self.pluginsDidLoadObserver = nil
        }
    }

    private func rebuildPipeline() {
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
            await sendMessageToAgent(message, conversationId)
        }
    }
}
