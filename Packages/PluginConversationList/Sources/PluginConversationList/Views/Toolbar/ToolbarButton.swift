import LumiUI
import SwiftUI

/// 工具栏会话列表按钮（复刻旧版 ConversationListPlugin.ToolbarButton）
///
/// 仅在「Chat 区块可见」且「全库至少存在一条对话」时渲染。任一条件不满足时
/// 整个按钮消失，键盘/工具栏流程自然略过它。
///
/// View 只依赖 `ConversationListToolbarViewModel`。
struct ToolbarButton: View {
    @ObservedObject private var viewModel: ConversationListToolbarViewModel
    let popoverAllViewModel: ConversationListViewModel
    let popoverCurrentViewModel: ConversationListViewModel
    @State private var isPresented = false

    init(
        viewModel: ConversationListToolbarViewModel,
        popoverAllViewModel: ConversationListViewModel,
        popoverCurrentViewModel: ConversationListViewModel
    ) {
        self.viewModel = viewModel
        self.popoverAllViewModel = popoverAllViewModel
        self.popoverCurrentViewModel = popoverCurrentViewModel
    }

    var body: some View {
        Group {
            if viewModel.isChatSectionVisible && viewModel.hasAnyConversations {
                AppIconButton(
                    systemImage: "message.fill"
                ) {
                    isPresented.toggle()
                }
                .popover(isPresented: $isPresented, arrowEdge: .bottom) {
                    ToolbarPopoverContent(
                        viewModel: viewModel,
                        allProjectsViewModel: popoverAllViewModel,
                        currentProjectViewModel: popoverCurrentViewModel
                    )
                }
            }
        }
        .task {
            await viewModel.refreshConversationPresence()
        }
        .onChange(of: viewModel.contextRevision) { _, _ in
            Task { await viewModel.refreshConversationPresence() }
        }
    }
}
