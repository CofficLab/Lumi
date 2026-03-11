import AppKit
import SwiftUI
import MagicKit

/// 基于 AppKit 的消息列表实现（SwiftUI 包装）
struct MessageListAppKitView: NSViewRepresentable, SuperLog {
    nonisolated static let emoji = "📜"
    nonisolated static let verbose = false

    typealias NSViewType = MessageListAppKitContainerView

    @EnvironmentObject var agentProvider: AgentProvider
    @EnvironmentObject var conversationViewModel: ConversationViewModel
    @EnvironmentObject var processingStateViewModel: ProcessingStateViewModel

    func makeNSView(context: Context) -> MessageListAppKitContainerView {
        MessageListAppKitContainerView(
            agentProvider: agentProvider,
            conversationViewModel: conversationViewModel,
            processingStateViewModel: processingStateViewModel
        )
    }

    func updateNSView(_ nsView: MessageListAppKitContainerView, context: Context) {
        nsView.updateDependencies(
            agentProvider: agentProvider,
            conversationViewModel: conversationViewModel,
            processingStateViewModel: processingStateViewModel
        )
    }
}

