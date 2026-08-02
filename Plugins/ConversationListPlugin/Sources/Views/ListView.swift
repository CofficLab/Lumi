import LumiKernel
import LumiUI
import SwiftUI

/// 对话列表视图
public struct ListView: View {
    @State private var conversations: [LumiConversationSummary] = []
    @State private var isLoading = true
    let svc: any ConversationManaging
    let kernel: LumiKernel
    let attentionStore: ConversationAttentionStore

    public init(kernel: LumiKernel, attentionStore: ConversationAttentionStore) {
        precondition(kernel.conversations != nil, "kernel.conversations is nil")
        self.svc = kernel.conversations!
        self.kernel = kernel
        self.attentionStore = attentionStore
    }

    public var body: some View {
        Group {
            if isLoading {
                ListLoadingView()
            } else if conversations.isEmpty {
                ListEmptyView()
            } else {
                listContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            await reload()
            for await _ in NotificationCenter.default.notifications(named: .lumiConversationsDidChange) {
                await reload()
            }
        }
    }

    private var listContent: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(conversations, id: \.id) { conversation in
                    ItemView(
                        conversation: conversation,
                        svc: svc,
                        kernel: kernel,
                        attentionStore: attentionStore
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .scrollContentBackground(.hidden)
    }

    private func reload() async {
        conversations = await MainActor.run {
            svc.sortedConversations
        }
        isLoading = false
    }
}
