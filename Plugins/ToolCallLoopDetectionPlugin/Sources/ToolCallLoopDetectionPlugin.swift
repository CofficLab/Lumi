import Foundation
import LumiCoreKit
import SuperLogKit
import os
import LumiUI
import SwiftUI

/// 工具调用循环检测插件
///
/// 监听数据库事件，在即将发起下一轮 LLM 请求前检测工具调用是否进入循环。
public actor ToolCallLoopDetectionPlugin: SuperPlugin, SuperLog {
    public nonisolated static let policy: PluginPolicy = .disabled
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.tool-call-loop-detection")
    public nonisolated static let emoji = "🔄"
    public nonisolated static let verbose: Bool = false
    public static let id = "tool-call-loop-detection"
    public static let displayName: String = LumiPluginLocalization.string("工具调用循环检测", bundle: .module)
    public static let description: String = LumiPluginLocalization.string("检测并防止工具调用进入无限循环。", bundle: .module)
    public static let iconName: String = "arrow.triangle.2.circlepath"
    public static var category: PluginCategory { .agent }
    /// 位于 ToolExecutor(195) 与 MessageSender(200) 之间，先于 MessageSender 响应 DB 事件。
    public static var order: Int { 198 }

    public static let shared = ToolCallLoopDetectionPlugin()

    private init() {}

    @MainActor
    public func configureRuntime(context: PluginRuntimeContext) {
        ToolCallLoopDetectionRuntimeBridge.loadMessages = context.loadMessages
        ToolCallLoopDetectionRuntimeBridge.loadTurnPhase = context.loadTurnPhase
        ToolCallLoopDetectionRuntimeBridge.saveMessage = context.saveMessage
        ToolCallLoopDetectionRuntimeBridge.setTurnPhase = context.setTurnPhase
        ToolCallLoopDetectionRuntimeBridge.isConversationCancelled = context.isConversationCancelled
        ToolCallLoopDetectionRuntimeBridge.markConversationCancelled = context.markConversationCancelled
        ToolCallLoopDetectionRuntimeBridge.releaseConversationLock = context.releaseConversationLock
        ToolCallLoopDetectionRuntimeBridge.finishAgentTurn = context.finishAgentTurn
        ToolCallLoopDetectionRuntimeBridge.setConversationStatus = context.setConversationStatus
    }

    @MainActor
    public func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(ToolCallLoopDetectionEventObserver(content: content()))
    }
}

private struct ToolCallLoopDetectionEventObserver<Content: View>: View {
    let content: Content

    var body: some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .messageSaved)) { notification in
                guard let conversationId = notification.userInfo?["conversationId"] as? UUID else { return }
                ToolCallLoopDetectionOrchestrator.handleMessageSaved(conversationId: conversationId)
            }
            .onReceive(NotificationCenter.default.publisher(for: .agentTurnPhaseChanged)) { notification in
                guard let conversationId = notification.object as? UUID else { return }
                guard notification.userInfo?["phase"] as? String == AgentTurnPhase.processing.rawValue else { return }
                ToolCallLoopDetectionOrchestrator.handleMessageSaved(conversationId: conversationId)
            }
    }
}
