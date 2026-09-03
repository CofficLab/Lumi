import LumiUI
import SwiftUI

/// 工具栏会话列表按钮（复刻旧版 ConversationListPlugin.ToolbarButton）
///
/// 仅在「Chat 区块可见」且「全库至少存在一条对话」时渲染。任一条件不满足时
/// 整个按钮消失，键盘/工具栏流程自然略过它。
struct ToolbarButton: View {
    @ObservedObject private var context: ConversationListContext
    let attentionStore: ConversationAttentionStore
    let sortStabilizer: ConversationSortStabilizer
    @State private var isPresented = false

    /// ChatSection 是否可见；不可见时整个按钮不渲染。
    ///
    /// ChatSectionProviding 是无约束协议，无法直接订阅 objectWillChange，
    /// 用轻量轮询跟随可见性变化（复刻旧版 onChatSectionVisibleDidChange）。
    @State private var isChatSectionVisible: Bool = true
    /// 全库是否存在任意对话；默认 true 以避免启动加载期间按钮闪烁，
    /// 异步查得数量为 0 时再隐藏。
    @State private var hasAnyConversations: Bool = true

    init(
        context: ConversationListContext,
        attentionStore: ConversationAttentionStore,
        sortStabilizer: ConversationSortStabilizer
    ) {
        self._context = ObservedObject(wrappedValue: context)
        self.attentionStore = attentionStore
        self.sortStabilizer = sortStabilizer
    }

    var body: some View {
        Group {
            if isChatSectionVisible && hasAnyConversations {
                AppIconButton(
                    systemImage: "message.fill"
                ) {
                    isPresented.toggle()
                }
                .popover(isPresented: $isPresented, arrowEdge: .bottom) {
                    ToolbarPopoverContent(
                        context: context,
                        attentionStore: attentionStore,
                        sortStabilizer: sortStabilizer
                    )
                }
            }
        }
        .task {
            await refreshConversationPresence()
        }
        .task {
            // 轮询 ChatSection 可见性：协议存在类型无法被 Combine 订阅，
            // 轻量轮询开销可忽略，且跟随容器切换即时收敛。
            while !Task.isCancelled {
                let visible = context.chat?.isVisible ?? true
                if isChatSectionVisible != visible {
                    isChatSectionVisible = visible
                }
                try? await Task.sleep(for: .milliseconds(300))
            }
        }
        .onChange(of: context.conversationsRevision) { _, _ in
            Task { await refreshConversationPresence() }
        }
    }

    /// 查询全库顶层对话总数，据此决定按钮是否值得展示：
    /// 全库没有任何对话时隐藏该入口，避免一个只能弹出空列表的按钮。
    private func refreshConversationPresence() async {
        let count = await context.conversations.conversationCount(projectPath: nil)
        hasAnyConversations = count > 0
    }
}
