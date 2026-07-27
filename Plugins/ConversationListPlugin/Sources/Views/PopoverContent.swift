import Foundation
import SwiftUI
import LumiKernel

/// 会话列表弹窗内容
struct PopoverContent: View {
    let kernel: LumiKernel
    @StateObject private var context: ConversationListContext

    init(kernel: LumiKernel) {
        self.kernel = kernel
        precondition(kernel.conversations != nil, "kernel.conversations is nil when creating ConversationListPopoverContent")
        _context = StateObject(
            wrappedValue: ConversationListContext(kernel: kernel)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Conversations")
                    .font(.headline)
                Spacer()
                Text("\(context.conversationCount)")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.secondary.opacity(0.12))
                    )
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            ConversationListView(context: context)
        }
    }
}
