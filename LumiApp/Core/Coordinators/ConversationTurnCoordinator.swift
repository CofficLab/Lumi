import Foundation
import OSLog
import MagicKit

/// 对话轮次事件协调器
///
/// 负责消费 `ConversationTurnViewModel.events`，并将事件交给上层处理；同时提供卡顿看门狗与耗时日志。
@MainActor
final class ConversationTurnCoordinator: SuperLog {
    nonisolated static let emoji = "🔁"
    nonisolated static let verbose = false

    private let conversationTurnViewModel: ConversationTurnViewModel
    private let runtimeStore: ConversationRuntimeStore
    private let env: Environment
    private let messages: MessageActions
    private let ui: UIActions
    private let onFallbackEvent: (ConversationTurnEvent) async -> Void

    private var task: Task<Void, Never>?
    private var pipeline: MiddlewarePipeline<ConversationTurnEvent, ConversationTurnMiddlewareContext>?
    private var pluginsDidLoadObserver: NSObjectProtocol?

    struct Environment {
        let selectedConversationId: () -> UUID?
        let maxThinkingTextLength: Int
        let immediateStreamFlushChars: Int
        let immediateThinkingFlushChars: Int
        let captureThinkingContent: Bool
    }

    struct MessageActions {
        let messages: () -> [ChatMessage]
        let appendMessage: (ChatMessage) -> Void
        let updateMessage: (ChatMessage, Int) -> Void
        let saveMessage: (ChatMessage, UUID) async -> Void
        let flushPendingStreamText: (UUID, Bool) -> Void
        let flushPendingThinkingText: (UUID, Bool) -> Void
        let updateRuntimeState: (UUID) -> Void
    }

    struct UIActions {
        let setPendingPermissionRequest: (PermissionRequest?, UUID) -> Void
        let setDepthWarning: (DepthWarning?, UUID) -> Void
        let setErrorMessage: (String?, UUID) -> Void
        let onTurnFinishedUI: (UUID) -> Void
        let onTurnFailedUI: (UUID, String) -> Void

        // streaming / UI hooks
        let onStreamStartedUI: (UUID, UUID) -> Void // (messageId, conversationId)
        let onStreamFirstTokenUI: (UUID, Double?) -> Void // (conversationId, ttftMs?)
        let onStreamFinishedUI: (UUID) -> Void // conversationId
        let onThinkingStartedUI: (UUID) -> Void // conversationId
        let setLastHeartbeatTime: (Date?) -> Void
        let setIsThinking: (Bool, UUID) -> Void
        let setThinkingText: (String, UUID) -> Void
    }

    init(
        conversationTurnViewModel: ConversationTurnViewModel,
        runtimeStore: ConversationRuntimeStore,
        env: Environment,
        messages: MessageActions,
        ui: UIActions,
        onFallbackEvent: @escaping (ConversationTurnEvent) async -> Void
    ) {
        self.conversationTurnViewModel = conversationTurnViewModel
        self.runtimeStore = runtimeStore
        self.messages = messages
        self.ui = ui
        self.env = env
        self.onFallbackEvent = onFallbackEvent
    }

    func start() {
        task?.cancel()

        // 确保在插件加载完成后重建一次 pipeline（避免启动早期读取 middleware 导致缓存为空）
        if pluginsDidLoadObserver == nil {
            pluginsDidLoadObserver = NotificationCenter.default.addObserver(
                forName: NSNotification.Name("PluginsDidLoad"),
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
            for await event in self.conversationTurnViewModel.events {
                let start = CFAbsoluteTimeGetCurrent()
                let eventName = self.describe(event)
                let hangWatchdog = Task { [loggerTag = Self.t] in
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    guard !Task.isCancelled else { return }
                    os_log(.error, "\(loggerTag)⏳ 事件处理疑似卡住(>2s): \(eventName)")
                }

                let ctx = ConversationTurnMiddlewareContext(
                    runtimeStore: self.runtimeStore,
                    env: self.env,
                    actions: self.messages,
                    ui: self.ui
                )

                if let pipeline = self.pipeline {
                    await pipeline.run(event, ctx: ctx) { event, _ in
                        await self.handle(event)
                    }
                } else {
                    await self.handle(event)
                }

                hangWatchdog.cancel()
                let elapsed = CFAbsoluteTimeGetCurrent() - start
                if elapsed > 1 {
                    os_log(.error, "\(Self.t)⏱️ 事件处理耗时异常: \(eventName) took \(String(format: "%.3f", elapsed))s")
                }
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func rebuildPipeline() {
        let pluginMiddlewares = PluginProvider.shared.getConversationTurnMiddlewares()
            .sorted { a, b in
                if a.order != b.order { return a.order < b.order }
                return a.id < b.id
            }

        let coreMiddlewares: [AnyConversationTurnMiddleware] = [
            AnyConversationTurnMiddleware(PingFilterMiddleware()),
            AnyConversationTurnMiddleware(ThinkingDeltaThrottleMiddleware()),
            AnyConversationTurnMiddleware(TraceLoggingMiddleware())
        ]

        let all = (coreMiddlewares + pluginMiddlewares).sorted { a, b in
            if a.order != b.order { return a.order < b.order }
            return a.id < b.id
        }

        pipeline = MiddlewarePipeline<ConversationTurnEvent, ConversationTurnMiddlewareContext>(
            middlewares: all.map { m in
                { event, ctx, next in
                    await m.handle(event: event, ctx: ctx, next: next)
                }
            }
        )
    }

    private func handle(_ event: ConversationTurnEvent) async {
        switch event {
        case let .responseReceived(message, conversationId):
            if env.selectedConversationId() == conversationId {
                messages.appendMessage(message)
            }
            await messages.saveMessage(message, conversationId)
            messages.updateRuntimeState(conversationId)

        case let .toolResultReceived(result, conversationId):
            if env.selectedConversationId() == conversationId {
                messages.appendMessage(result)
            }
            await messages.saveMessage(result, conversationId)
            messages.updateRuntimeState(conversationId)

        case let .permissionRequested(request, conversationId):
            runtimeStore.pendingPermissionByConversation[conversationId] = request
            if env.selectedConversationId() == conversationId {
                ui.setPendingPermissionRequest(request, conversationId)
            }
            messages.updateRuntimeState(conversationId)

        case let .maxDepthReached(currentDepth, maxDepth, conversationId):
            let warning = DepthWarning(currentDepth: currentDepth, maxDepth: maxDepth, warningType: .reached)
            runtimeStore.depthWarningByConversation[conversationId] = warning
            runtimeStore.processingConversationIds.remove(conversationId)

            if env.selectedConversationId() == conversationId {
                ui.setDepthWarning(warning, conversationId)
                ui.onTurnFinishedUI(conversationId)
            }

            runtimeStore.streamStateByConversation[conversationId] = .init(messageId: nil, messageIndex: nil)
            runtimeStore.pendingStreamTextByConversation[conversationId] = nil
            runtimeStore.pendingThinkingTextByConversation[conversationId] = nil
            runtimeStore.lastStreamFlushAtByConversation[conversationId] = nil
            runtimeStore.lastThinkingFlushAtByConversation[conversationId] = nil
            runtimeStore.streamStartedAtByConversation[conversationId] = nil
            runtimeStore.didReceiveFirstTokenByConversation.remove(conversationId)
            messages.updateRuntimeState(conversationId)

        case let .completed(conversationId):
            runtimeStore.processingConversationIds.remove(conversationId)

            if env.selectedConversationId() == conversationId {
                ui.onTurnFinishedUI(conversationId)
            }

            runtimeStore.streamStateByConversation[conversationId] = .init(messageId: nil, messageIndex: nil)
            runtimeStore.pendingStreamTextByConversation[conversationId] = nil
            runtimeStore.pendingThinkingTextByConversation[conversationId] = nil
            runtimeStore.lastStreamFlushAtByConversation[conversationId] = nil
            runtimeStore.lastThinkingFlushAtByConversation[conversationId] = nil
            runtimeStore.streamStartedAtByConversation[conversationId] = nil
            runtimeStore.didReceiveFirstTokenByConversation.remove(conversationId)
            messages.updateRuntimeState(conversationId)

        case let .error(error, conversationId):
            let msg = error.localizedDescription
            runtimeStore.errorMessageByConversation[conversationId] = msg
            runtimeStore.processingConversationIds.remove(conversationId)

            if env.selectedConversationId() == conversationId {
                ui.setErrorMessage(msg, conversationId)
                ui.onTurnFailedUI(conversationId, msg)
            }

            runtimeStore.streamStateByConversation[conversationId] = .init(messageId: nil, messageIndex: nil)
            runtimeStore.pendingStreamTextByConversation[conversationId] = nil
            runtimeStore.pendingThinkingTextByConversation[conversationId] = nil
            runtimeStore.lastStreamFlushAtByConversation[conversationId] = nil
            runtimeStore.lastThinkingFlushAtByConversation[conversationId] = nil
            runtimeStore.streamStartedAtByConversation[conversationId] = nil
            runtimeStore.didReceiveFirstTokenByConversation.remove(conversationId)
            messages.updateRuntimeState(conversationId)

        case let .streamStarted(messageId, conversationId):
            runtimeStore.streamStateByConversation[conversationId] = .init(messageId: messageId, messageIndex: nil)
            runtimeStore.pendingStreamTextByConversation[conversationId] = ""
            runtimeStore.pendingThinkingTextByConversation[conversationId] = ""
            runtimeStore.lastStreamFlushAtByConversation[conversationId] = Date()
            runtimeStore.lastThinkingFlushAtByConversation[conversationId] = Date()
            runtimeStore.streamStartedAtByConversation[conversationId] = Date()
            runtimeStore.didReceiveFirstTokenByConversation.remove(conversationId)

            runtimeStore.thinkingTextByConversation[conversationId] = ""
            runtimeStore.thinkingConversationIds.remove(conversationId)

            if env.selectedConversationId() == conversationId {
                ui.setThinkingText("", conversationId)
                ui.setIsThinking(false, conversationId)
                ui.onStreamStartedUI(messageId, conversationId)
            }

            let placeholderMessage = ChatMessage(id: messageId, role: .assistant, content: "", timestamp: Date())
            if env.selectedConversationId() == conversationId {
                messages.appendMessage(placeholderMessage)
                runtimeStore.streamStateByConversation[conversationId]?.messageIndex = messages.messages().count - 1
            }
            messages.updateRuntimeState(conversationId)

        case let .streamChunk(content, messageId, conversationId):
            guard env.selectedConversationId() == conversationId,
                  runtimeStore.streamStateByConversation[conversationId]?.messageId == messageId else {
                return
            }

            if !runtimeStore.didReceiveFirstTokenByConversation.contains(conversationId) {
                runtimeStore.didReceiveFirstTokenByConversation.insert(conversationId)
                if let startedAt = runtimeStore.streamStartedAtByConversation[conversationId] {
                    let ttftMs = Date().timeIntervalSince(startedAt) * 1000.0
                    ui.onStreamFirstTokenUI(conversationId, ttftMs)
                } else {
                    ui.onStreamFirstTokenUI(conversationId, nil)
                }
            }

            runtimeStore.pendingStreamTextByConversation[conversationId, default: ""] += content
            messages.flushPendingStreamText(
                conversationId,
                runtimeStore.pendingStreamTextByConversation[conversationId, default: ""].count >= env.immediateStreamFlushChars
            )

        case let .streamEvent(eventType, content, rawEvent, messageId, conversationId):
            if eventType == .ping {
                let now = Date()
                if let last = runtimeStore.lastHeartbeatByConversation[conversationId] ?? nil,
                   now.timeIntervalSince(last) < 0.8 {
                    return
                }
                runtimeStore.lastHeartbeatByConversation[conversationId] = now
                if env.selectedConversationId() == conversationId {
                    ui.setLastHeartbeatTime(now)
                }
                return
            }

            if eventType == .thinkingDelta {
                guard env.captureThinkingContent else { return }
                if !content.isEmpty {
                    let existing = runtimeStore.thinkingTextByConversation[conversationId, default: ""]
                    if existing.count < env.maxThinkingTextLength {
                        let remaining = env.maxThinkingTextLength - existing.count
                        let appendPart = String(content.prefix(remaining))
                        runtimeStore.thinkingTextByConversation[conversationId] = existing + appendPart
                        if env.selectedConversationId() == conversationId, !appendPart.isEmpty {
                            runtimeStore.pendingThinkingTextByConversation[conversationId, default: ""] += appendPart
                            messages.flushPendingThinkingText(
                                conversationId,
                                runtimeStore.pendingThinkingTextByConversation[conversationId, default: ""].count >= env.immediateThinkingFlushChars
                            )
                        }
                    }
                }
                return
            }

            if eventType == .contentBlockStart {
                if rawEvent.contains("\"type\":\"thinking\"") || rawEvent.contains("thinking") {
                    runtimeStore.thinkingConversationIds.insert(conversationId)
                    if env.selectedConversationId() == conversationId {
                        ui.onThinkingStartedUI(conversationId)
                    }
                }
                return
            }

            if eventType == .contentBlockStop || eventType == .signatureDelta || eventType == .inputJsonDelta || eventType == .textDelta || eventType == .messageDelta {
                return
            }

            guard env.selectedConversationId() == conversationId,
                  runtimeStore.streamStateByConversation[conversationId]?.messageId == messageId,
                  let index = runtimeStore.streamStateByConversation[conversationId]?.messageIndex,
                  index < messages.messages().count else {
                return
            }

            if eventType == .textDelta {
                var currentMessage = messages.messages()[index]
                currentMessage.content += content
                messages.updateMessage(currentMessage, index)
            }

        case let .streamFinished(message, conversationId):
            messages.flushPendingStreamText(conversationId, true)
            messages.flushPendingThinkingText(conversationId, true)

            var finalMessage = message
            let thinkingText = runtimeStore.thinkingTextByConversation[conversationId] ?? ""
            if !thinkingText.isEmpty {
                finalMessage.thinkingContent = thinkingText
            }

            if env.selectedConversationId() == conversationId,
               let index = runtimeStore.streamStateByConversation[conversationId]?.messageIndex,
               index < messages.messages().count {
                messages.updateMessage(finalMessage, index)
            }
            await messages.saveMessage(finalMessage, conversationId)

            runtimeStore.streamStateByConversation[conversationId] = .init(messageId: nil, messageIndex: nil)
            runtimeStore.thinkingConversationIds.remove(conversationId)

            if env.selectedConversationId() == conversationId {
                ui.onStreamFinishedUI(conversationId)
            }

            runtimeStore.pendingStreamTextByConversation[conversationId] = nil
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
        case .maxDepthReached: return "maxDepthReached"
        case .completed: return "completed"
        case .error: return "error"
        case .shouldContinue: return "shouldContinue"
        }
    }
}

