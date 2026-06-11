import SwiftUI
import LumiCoreKit
import SuperLogKit
import os

/// DB 队列插件：出队 pending 消息、运行 SendPipeline、设置 turnPhase 启动插件链。
public actor SendQueuePlugin: SuperPlugin, SuperLog {
    nonisolated public static let emoji = "📥"
    public static var category: PluginCategory { .agent }
    nonisolated public static let verbose: Bool = false
    nonisolated public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.send-queue")

    nonisolated public static let policy: PluginPolicy = .alwaysOn

    public static let id = "SendQueue"
    public static let displayName = String(localized: "Send Queue", bundle: .module)
    public static let description = String(localized: "Dequeue pending messages and run send prepare pipeline", bundle: .module)
    public static let iconName = "tray.and.arrow.down"
    public static var order: Int { 190 }

    nonisolated public var instanceLabel: String { Self.id }
    public static let shared = SendQueuePlugin()

    private init() {}

    @MainActor
    public func configureRuntime(context: PluginRuntimeContext) {
        SendQueueRuntimeBridge.loadMessages = context.loadMessages
        SendQueueRuntimeBridge.loadTurnPhase = context.loadTurnPhase
        SendQueueRuntimeBridge.setTurnPhase = context.setTurnPhase
        SendQueueRuntimeBridge.tryAcquireConversationLock = context.tryAcquireConversationLock
        SendQueueRuntimeBridge.releaseConversationLock = context.releaseConversationLock
        SendQueueRuntimeBridge.isConversationCancelled = context.isConversationCancelled
        SendQueueRuntimeBridge.clearConversationCancelled = context.clearConversationCancelled
        SendQueueRuntimeBridge.dequeueNextPendingMessage = context.dequeueNextPendingMessage
        SendQueueRuntimeBridge.runSendPreparePipeline = context.runSendPreparePipeline
        SendQueueRuntimeBridge.storeTransientSystemPrompts = context.storeTransientSystemPrompts
    }

    @MainActor
    public func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(SendQueueEventObserver(content: content()))
    }
}

private struct SendQueueEventObserver<Content: View>: View {
    let content: Content

    var body: some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .messageSaved)) { notification in
                guard let conversationId = notification.userInfo?["conversationId"] as? UUID else { return }
                SendQueueOrchestrator.handleDatabaseEvent(conversationId: conversationId)
            }
            .onReceive(NotificationCenter.default.publisher(for: .agentTurnPhaseChanged)) { notification in
                guard let conversationId = notification.object as? UUID else { return }
                guard notification.userInfo?["phase"] as? String == AgentTurnPhase.idle.rawValue else { return }
                SendQueueOrchestrator.handleDatabaseEvent(conversationId: conversationId)
            }
    }
}
