import LumiKernel
import LumiUI
import os
import SuperLogKit
import SwiftUI

/// Rail 面板视图
struct RailView: View, SuperLog {
    let kernel: LumiKernel

    public nonisolated static let emoji = "💬"
    public nonisolated(unsafe) static var verbose = true
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "conversation-list.rail")

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            ConversationListView(kernel: kernel)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
