import KernelLumi
import LumiUI
import SwiftUI

/// 工具栏会话列表按钮
///
/// 仅在「Chat 区块可见」且「全库至少存在一条对话」时渲染。任一条件不满足时
/// 整个按钮消失，键盘/工具栏流程自然略过它
/// （参考 `ConversationNewPlugin.NewChatButton` 的模式）。
struct ToolbarButton: View {
    let kernel: KernelLumi
    let attentionStore: ConversationAttentionStore
    let sortStabilizer: ConversationSortStabilizer
    @State private var isPresented = false

    /// ChatSection 是否可见；不可见时整个按钮不渲染。
    @State private var isChatSectionVisible: Bool = true
    /// 全库是否存在任意对话；默认 true 以避免启动加载期间按钮闪烁，
    /// 异步查得数量为 0 时再隐藏。
    @State private var hasAnyConversations: Bool = true

    var body: some View {
        Group {
            if isChatSectionVisible && hasAnyConversations {
                AppIconButton(
                    systemImage: "message.fill",
                ) {
                    isPresented.toggle()
                }
                .popover(isPresented: $isPresented, arrowEdge: .bottom) {
                    ToolbarPopoverContent(kernel: kernel, attentionStore: attentionStore, sortStabilizer: sortStabilizer)
                }
            }
        }
        .onAppear {
            isChatSectionVisible = kernel.workspace?.isChatVisible ?? true
        }
        .onChatSectionVisibleDidChange { visible in
            isChatSectionVisible = visible
        }
        .task {
            await refreshConversationPresence()
        }
        .onLumiConversationsDidChange {
            Task { await refreshConversationPresence() }
        }
    }

    /// 查询全库顶层对话总数，据此决定按钮是否值得展示：
    /// 全库没有任何对话时隐藏该入口，避免一个只能弹出空列表的按钮。
    private func refreshConversationPresence() async {
        let count = await kernel.conversations?.conversationCount(projectPath: nil) ?? 0
        hasAnyConversations = count > 0
    }
}
