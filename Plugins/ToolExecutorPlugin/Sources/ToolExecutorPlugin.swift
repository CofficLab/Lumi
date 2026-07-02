import SwiftUI
import LumiCoreKit
import SuperLogKit
import os

/// Tool Executor 插件
///
/// 监听数据库事件，当检测到工具调用消息时执行工具调用，
/// 并将结果写回数据库。
public enum ToolExecutorPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .agent
    public static let iconName = "wrench.and.screwdriver"

    public static let info = LumiPluginInfo(
        id: "toolExecutor",
        displayName: LumiPluginLocalization.string("Tool Executor", bundle: .module),
        description: LumiPluginLocalization.string("Execute tool calls and write results to the database.", bundle: .module),
        order: 40
    )

    public static func configureRuntime(context: PluginRuntimeContext) {
        ToolExecutorRuntimeBridge.configureRuntime(context)
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

