import SwiftUI
import LumiCoreKit

public enum TurnLifecyclePlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .agent
    public static let iconName = "flag.checkered"

    public static let info = LumiPluginInfo(
        id: "TurnLifecycle",
        displayName: LumiPluginLocalization.string("Turn Lifecycle", bundle: .module),
        description: LumiPluginLocalization.string("Detect turn completion and run turn-finished pipeline", bundle: .module),
        order: 210
    )
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
