import SwiftUI
import LumiCoreKit

public actor TurnLifecyclePlugin: SuperPlugin {
    nonisolated public static let emoji = "🏁"
    public static var category: PluginCategory { .agent }
    nonisolated public static let policy: PluginPolicy = .alwaysOn

    public static let id = "TurnLifecycle"
    public static let displayName = LumiPluginLocalization.string("Turn Lifecycle", bundle: .module)
    public static let description = LumiPluginLocalization.string("Detect turn completion and run turn-finished pipeline", bundle: .module)
    public static let iconName = "flag.checkered"
    public static var order: Int { 210 }

    nonisolated public var instanceLabel: String { Self.id }
    public static let shared = TurnLifecyclePlugin()

    private init() {}

    @MainActor
    public func configureRuntime(context: PluginRuntimeContext) {
        TurnLifecycleRuntimeBridge.loadMessages = context.loadMessages
        TurnLifecycleRuntimeBridge.loadTurnPhase = context.loadTurnPhase
        TurnLifecycleRuntimeBridge.setTurnPhase = context.setTurnPhase
        TurnLifecycleRuntimeBridge.releaseConversationLock = context.releaseConversationLock
        TurnLifecycleRuntimeBridge.finishAgentTurn = context.finishAgentTurn
    }

    @MainActor
    public func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(TurnLifecycleEventObserver(content: content()))
    }
}

private struct TurnLifecycleEventObserver<Content: View>: View {
    let content: Content

    var body: some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .messageSaved)) { notification in
                guard let conversationId = notification.userInfo?["conversationId"] as? UUID else { return }
                TurnLifecycleOrchestrator.handleMessageSaved(conversationId: conversationId)
            }
            .onReceive(NotificationCenter.default.publisher(for: .agentTurnPhaseChanged)) { notification in
                guard let conversationId = notification.object as? UUID else { return }
                guard notification.userInfo?["phase"] as? String == AgentTurnPhase.processing.rawValue else { return }
                TurnLifecycleOrchestrator.handleMessageSaved(conversationId: conversationId)
            }
    }
}
