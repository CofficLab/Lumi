import SwiftUI
import MagicKit
import os

/// 延时消息插件的 RootView 覆盖层
///
/// 职责：从 SwiftUI Environment 获取 VM 引用，同步到 `DelayMessageState`。
/// 这是插件访问 VM 的唯一入口——不依赖 RootViewContainer.shared。
@MainActor
struct DelayMessageOverlay<Content: View>: View, SuperLog {
    nonisolated static var emoji: String { "⏳" }
    nonisolated static var verbose: Bool { DelayMessagePlugin.verbose }
    nonisolated static var logger: Logger {
        Logger(subsystem: "com.coffic.lumi", category: "delay-message.overlay")
    }

    let content: Content

    @EnvironmentObject private var conversationVM: ConversationVM
    @EnvironmentObject private var messageQueueVM: MessageQueueVM

    @State private var hasAppeared = false

    var body: some View {
        content
            .onAppear {
                guard !hasAppeared else { return }
                hasAppeared = true
                syncAll()
            }
            .onChange(of: conversationVM.selectedConversationId) { _, newId in
                DelayMessageState.shared.syncConversationId(newId)
            }
    }

    private func syncAll() {
        // 同步 VM 引用（只需一次）
        DelayMessageState.shared.syncMessageQueueVM(messageQueueVM)
        // 同步当前会话 ID
        DelayMessageState.shared.syncConversationId(conversationVM.selectedConversationId)

        if Self.verbose {
            Self.logger.info("\(Self.t)✅ 已同步 VM 引用到 DelayMessageState")
        }
    }
}