import LumiKernel
import LumiUI
import os
import SuperLogKit
import SwiftUI

/// Rail 面板视图
struct RailView: View, SuperLog {
    let kernel: LumiKernel

    public nonisolated static let emoji = "💬"
    public nonisolated(unsafe) static var verbose = false
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "conversation-list.rail")

    @State private var context: ConversationListContext?

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            if let ctx = context {
                ConversationListView(context: ctx)
            } else {
                ConversationListEmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            if context == nil, let conversations = kernel.conversations {
                context = ConversationListContext(
                    conversationManaging: conversations,
                    messageManaging: kernel.messageManager
                )
            }
        }
    }
}
