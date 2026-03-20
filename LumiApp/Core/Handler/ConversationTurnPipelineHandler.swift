import Foundation
import MagicKit

/// 消费 `ConversationTurnVM.events` 并跑中间件链；由 `RootView.task` 挂接生命周期（流式 chunk 高频，不宜用 `onChange` 驱动）。
@MainActor
final class ConversationTurnPipelineHandler: SuperLog {
    nonisolated static let emoji = "🔁"
    nonisolated static let verbose = false

    private let conversationTurnViewModel: ConversationTurnVM
    private let runtimeStore: ConversationRuntimeStore
    private let env: ConversationTurnMiddlewareEnvironment
    private let messages: ConversationTurnMiddlewareMessageActions
    private let ui: ConversationTurnMiddlewareUIActions
    private let onFallbackEvent: (ConversationTurnEvent) async -> Void

    private var pipeline: ConversationTurnPipeline?
    private var pluginsDidLoadObserver: NSObjectProtocol?

    init(
        conversationTurnViewModel: ConversationTurnVM,
        runtimeStore: ConversationRuntimeStore,
        env: ConversationTurnMiddlewareEnvironment,
        messages: ConversationTurnMiddlewareMessageActions,
        ui: ConversationTurnMiddlewareUIActions,
        onFallbackEvent: @escaping (ConversationTurnEvent) async -> Void
    ) {
        self.conversationTurnViewModel = conversationTurnViewModel
        self.runtimeStore = runtimeStore
        self.messages = messages
        self.ui = ui
        self.env = env
        self.onFallbackEvent = onFallbackEvent
    }

    func run() async {
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
        defer {
            if let pluginsDidLoadObserver {
                NotificationCenter.default.removeObserver(pluginsDidLoadObserver)
                self.pluginsDidLoadObserver = nil
            }
        }

        for await event in conversationTurnViewModel.events {
            if Task.isCancelled { break }

            let start = CFAbsoluteTimeGetCurrent()
            let eventName = describe(event)
            let hangWatchdog = Task { [loggerTag = Self.t] in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled else { return }
                AppLogger.core.error("\(loggerTag)⏳ 事件处理疑似卡住(>2s): \(eventName)")
            }

            let ctx = ConversationTurnMiddlewareContext(
                runtimeStore: runtimeStore,
                env: env,
                actions: messages,
                ui: ui
            )

            if let pipeline {
                await pipeline.run(event, ctx: ctx) { event, _ in
                    await self.handle(event)
                }
            } else {
                await handle(event)
            }

            hangWatchdog.cancel()
            let elapsed = CFAbsoluteTimeGetCurrent() - start
            if elapsed > 1 {
                AppLogger.core.error("\(Self.t)⏱️ 事件处理耗时异常: \(eventName) took \(String(format: "%.3f", elapsed))s")
            }
        }
    }

    private func rebuildPipeline() {
        let pluginMiddlewares = PluginVM.shared.getConversationTurnMiddlewares()
            .sorted { a, b in
                if a.order != b.order { return a.order < b.order }
                return a.id < b.id
            }

        let coreMiddlewares: [AnyConversationTurnMiddleware] = [
            AnyConversationTurnMiddleware(PingFilterMiddleware()),
            AnyConversationTurnMiddleware(PingHeartbeatMiddleware()),
            AnyConversationTurnMiddleware(StreamStartedInitializeMiddleware()),
            AnyConversationTurnMiddleware(StreamChunkAccumulateMiddleware()),
            AnyConversationTurnMiddleware(ThinkingDeltaCaptureMiddleware()),
            AnyConversationTurnMiddleware(ContentBlockThinkingStartMiddleware()),
            AnyConversationTurnMiddleware(PermissionDecisionMiddleware()),
            AnyConversationTurnMiddleware(StreamEventIgnoreMiddleware()),
            AnyConversationTurnMiddleware(StreamTextDeltaApplyMiddleware()),
            AnyConversationTurnMiddleware(EmptyToolResponseContentMiddleware()),
            AnyConversationTurnMiddleware(ToolResultTruncateMiddleware()),
            AnyConversationTurnMiddleware(StreamFinishedFinalizeMiddleware()),
            AnyConversationTurnMiddleware(MaxDepthReachedFinalizeMiddleware()),
            AnyConversationTurnMiddleware(TurnCompletedFinalizeMiddleware()),
            AnyConversationTurnMiddleware(PersistAndAppendMiddleware()),
            AnyConversationTurnMiddleware(ShouldContinueEnqueueMiddleware()),
            AnyConversationTurnMiddleware(TraceLoggingMiddleware())
        ]

        let all = (coreMiddlewares + pluginMiddlewares).sorted { a, b in
            if a.order != b.order { return a.order < b.order }
            return a.id < b.id
        }

        pipeline = ConversationTurnPipeline(
            middlewares: all.map { m in
                { event, ctx, next in
                    await m.handle(event: event, ctx: ctx, next: next)
                }
            }
        )
    }

    private func handle(_ event: ConversationTurnEvent) async {
        switch event {
        case let .error(error, conversationId):
            let msg = error.localizedDescription
            runtimeStore.errorMessageByConversation[conversationId] = msg
            runtimeStore.processingConversationIds.remove(conversationId)

            if env.selectedConversationId() == conversationId {
                ui.onTurnFailedUI(conversationId, msg)
            }

            runtimeStore.streamStateByConversation[conversationId] = .init(messageId: nil)
            runtimeStore.pendingStreamTextByConversation[conversationId] = nil
            runtimeStore.streamingTextByConversation[conversationId] = nil
            runtimeStore.pendingThinkingTextByConversation[conversationId] = nil
            runtimeStore.lastStreamFlushAtByConversation[conversationId] = nil
            runtimeStore.lastThinkingFlushAtByConversation[conversationId] = nil
            runtimeStore.streamStartedAtByConversation[conversationId] = nil
            runtimeStore.didReceiveFirstTokenByConversation.remove(conversationId)
            messages.updateRuntimeState(conversationId)

        default:
            await onFallbackEvent(event)
        }
    }

    private func describe(_ event: ConversationTurnEvent) -> String {
        switch event {
        case .responseReceived: return "responseReceived"
        case .streamChunk: return "streamChunk"
        case .streamEvent: return "streamEvent"
        case .streamStarted: return "streamStarted"
        case .streamFinished: return "streamFinished"
        case .toolResultReceived: return "toolResultReceived"
        case .permissionRequested: return "permissionRequested"
        case .permissionDecision: return "permissionDecision"
        case .maxDepthReached: return "maxDepthReached"
        case .completed: return "completed"
        case .error: return "error"
        case .shouldContinue: return "shouldContinue"
        }
    }
}
