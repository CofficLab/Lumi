import ProviderConversation
import SwiftUI

/// 对话列表视图：
/// - 分页加载（每页 40），滚动到底自动加载下一页；
/// - 粘性排序（ConversationSortStabilizer），防止高频消息导致列表跳动；
/// - 乐观选中：点击时立刻高亮，再与管理器真实状态对齐；
/// - 首次加载显示骨架屏，已有内容刷新时保持旧列表可见；
/// - 对话变化（增删/标题/项目迁移）由 ViewModel 内部观察并自动刷新。
///
/// View 只依赖 `ConversationListViewModel`，不持有任何 Provider / Observer。
struct ListView: View {
    @ObservedObject private var viewModel: ConversationListViewModel

    init(viewModel: ConversationListViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(spacing: 0) {
            mainContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            await viewModel.loadInitialIfNeeded()
        }
        .task(id: viewModel.resolvedProjectPath) {
            await viewModel.loadInitialIfNeeded()
        }
        // 项目切换或列表结构变化时刷新。
        .onChange(of: viewModel.resolvedProjectPath) { _, _ in
            Task { @MainActor in
                await viewModel.reload()
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if viewModel.isLoading {
            ListLoadingView()
        } else if viewModel.conversations.isEmpty {
            ListEmptyView()
        } else {
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(viewModel.conversations, id: \.id) { conversation in
                        ItemView(
                            conversation: conversation,
                            conversationState: viewModel.conversationState(for: conversation.id),
                            isSelected: (viewModel.immediateSelectionID ?? viewModel.selectedConversationID) == conversation.id,
                            needsAttention: viewModel.needsAttention(for: conversation.id),
                            onSelect: {
                                viewModel.selectConversation(id: conversation.id)
                            },
                            onDelete: {
                                viewModel.deleteConversation(id: conversation.id)
                            }
                        )
                    }

                    if viewModel.hasMore {
                        ProgressView()
                            .controlSize(.small)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .onAppear {
                                Task { await viewModel.loadNextPage() }
                            }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .scrollContentBackground(.hidden)
        }
    }
}
