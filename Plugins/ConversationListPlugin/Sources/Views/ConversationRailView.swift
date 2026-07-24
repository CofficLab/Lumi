import LumiKernel
import LumiUI
import SuperLogKit
import SwiftUI
import os

/// Rail 面板视图
struct ConversationRailView: View, SuperLog {
    let kernel: LumiKernel

    nonisolated public static let emoji = "💬"
    nonisolated(unsafe) public static var verbose = false
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
                context = ConversationListContext(conversationManaging: conversations)
            }
        }
    }
}
