import SwiftUI
import LumiCoreKit
import SuperLogKit
import os

public actor ToolExecutorPlugin: SuperPlugin, SuperLog {
    nonisolated public static let emoji = "🔧"
    public static var category: PluginCategory { .agent }
    nonisolated public static let policy: PluginPolicy = .alwaysOn
    nonisolated public static let verbose = true

    public static let id = "ToolExecutor"
    public static let displayName = LumiPluginLocalization.string("Tool Executor", bundle: .module)
    public static let description = LumiPluginLocalization.string("Execute Agent tool calls and write results to the database", bundle: .module)
    public static let iconName = "wrench.and.screwdriver"
    public static var order: Int { 195 }

    nonisolated public var instanceLabel: String { Self.id }
    public static let shared = ToolExecutorPlugin()

    private init() {}

    @MainActor
    public func configureRuntime(context: PluginRuntimeContext) {
        ToolExecutorRuntimeBridge.loadMessages = context.loadMessages
        ToolExecutorRuntimeBridge.loadTurnPhase = context.loadTurnPhase
        ToolExecutorRuntimeBridge.setTurnPhase = context.setTurnPhase
        ToolExecutorRuntimeBridge.tryAcquireConversationLock = context.tryAcquireConversationLock
        ToolExecutorRuntimeBridge.releaseConversationLock = context.releaseConversationLock
        ToolExecutorRuntimeBridge.isConversationCancelled = context.isConversationCancelled
        ToolExecutorRuntimeBridge.presentToolPermissionIfNeeded = context.presentToolPermissionIfNeeded
        ToolExecutorRuntimeBridge.executeToolCalls = context.executeToolCalls
        ToolExecutorRuntimeBridge.finishAgentTurn = context.finishAgentTurn
        ToolExecutorRuntimeBridge.setConversationStatus = context.setConversationStatus
    }

    @MainActor
    public func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(ToolExecutorEventObserver(content: content()))
    }
}

private struct ToolExecutorEventObserver<Content: View>: View {
    let content: Content

    var body: some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .messageSaved)) { notification in
                guard let conversationId = notification.userInfo?["conversationId"] as? UUID else { return }
                ToolExecutorOrchestrator.handleMessageSaved(conversationId: conversationId)
            }
            .onReceive(NotificationCenter.default.publisher(for: .agentTurnPhaseChanged)) { notification in
                guard let conversationId = notification.object as? UUID else { return }
                guard notification.userInfo?["phase"] as? String == AgentTurnPhase.processing.rawValue else { return }
                ToolExecutorOrchestrator.handleMessageSaved(conversationId: conversationId)
            }
    }
}
