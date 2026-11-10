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
    @StateObject private var popoverState = ToolbarPopoverState()

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
                toolbarButton
            }
        }
        .task {
            await viewModel.refreshConversationPresence()
        }
        .onChange(of: viewModel.contextRevision) { _ in
            Task { await viewModel.refreshConversationPresence() }
        }
    }

    private var button: some View {
        AppIconButton(
            systemImage: "message.fill",
            isActive: popoverState.isPresented
        ) {
            popoverState.isPresented.toggle()
        }
        .accessibilityLabel(pluginLocalization.string("Chats"))
    }

    #if os(macOS)
    private var toolbarButton: some View {
        button
            // macOS 的 SwiftUI `.popover` 无法切换常驻行为，用 AppKit 宿主替换。
            .background(
                ConversationListPopoverPresenter(
                    isPresented: $popoverState.isPresented,
                    isPinned: $popoverState.isPinned
                ) {
                    popoverContent
                }
            )
    }
    #else
    private var toolbarButton: some View {
        button
            .popover(isPresented: $popoverState.isPresented, arrowEdge: .bottom) {
                popoverContent
            }
    }
    #endif

    private var popoverContent: some View {
        ToolbarPopoverContent(
            viewModel: viewModel,
            allProjectsViewModel: popoverAllViewModel,
            currentProjectViewModel: popoverCurrentViewModel,
            pinState: popoverState
        )
    }
}

/// 工具栏 popover 的展示状态。
///
/// 图钉状态只在本次弹窗生命周期内有效：关闭后由 presenter 重置为未钉住，
/// 下次打开仍从默认的临时浮层行为开始（避免「下次普通点击打开却关不掉」的隐性状态）。
final class ToolbarPopoverState: ObservableObject {
    @Published var isPresented = false
    @Published var isPinned = false
}
