import Combine
import LumiKernel
import LumiUI
import SwiftUI

/// 对话列表视图
public struct ListView: View {
    @State private var conversations: [LumiConversationSummary] = []
    @State private var isLoaded = false
    let svc: any ConversationManaging

    public init(kernel: LumiKernel) {
        precondition(kernel.conversations != nil, "kernel.conversations is nil")
        self.svc = kernel.conversations!
    }

    public var body: some View {
        Group {
            if !isLoaded || conversations.isEmpty {
                ListLoadingView()
            } else {
                listContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            await loadConversations()
        }
    }

    private var listContent: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(conversations, id: \.id) { conversation in
                    AppListRow(isSelected: svc.selectedConversationID == conversation.id) {
                        ItemView(
                            conversation: conversation,
                            onDelete: { svc.deleteConversation(id: conversation.id) },
                            onPin: {
                                let newOrder = conversation.order == 0 ? LumiConversationSummary.defaultOrder : 0
                                svc.setConversationOrder(newOrder, for: conversation.id)
                            }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            svc.selectConversation(id: conversation.id)
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .scrollContentBackground(.hidden)
    }

    private func loadConversations() async {
        conversations = await MainActor.run {
            svc.conversations.sorted { lhs, rhs in
                if lhs.order != rhs.order {
                    return lhs.order < rhs.order
                }
                if lhs.updatedAt == rhs.updatedAt {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.updatedAt > rhs.updatedAt
            }
        }
        isLoaded = true
    }
}

/// 加载视图
private struct ListLoadingView: View {
    var body: some View {
        ProgressView()
            .controlSize(.small)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}