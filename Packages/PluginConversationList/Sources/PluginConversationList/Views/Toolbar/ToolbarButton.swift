import LumiUI
import ProviderChatSection
import SwiftUI

/// 工具栏会话列表按钮（复刻旧版 ConversationListPlugin.ToolbarButton）
///
/// 仅在「Chat 区块可见」且「全库至少存在一条对话」时渲染。任一条件不满足时
/// 整个按钮消失，键盘/工具栏流程自然略过它。
struct ToolbarButton: View {
    private let context: ConversationListContext
    let attentionStore: ConversationAttentionStore
    let sortStabilizer: ConversationSortStabilizer
    @State private var isPresented = false

    /// ChatSection 是否可见；不可见时整个按钮不渲染。
    @State private var isChatSectionVisible: Bool = true
    @State private var chatObserverHandle: (any ChatSectionProvidingObserverHandle)?
    /// 全库是否存在任意对话；默认 true 以避免启动加载期间按钮闪烁，
    /// 异步查得数量为 0 时再隐藏。
    @State private var hasAnyConversations: Bool = true
    @State private var contextRevision = 0
    @State private var contextObserverHandle: (any ConversationListContext.ObserverHandle)?

    init(
        context: ConversationListContext,
        attentionStore: ConversationAttentionStore,
        sortStabilizer: ConversationSortStabilizer
    ) {
        self.context = context
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
        .onAppear {
            isChatSectionVisible = context.chat?.isVisible ?? true
            guard chatObserverHandle == nil else { return }
            chatObserverHandle = context.chat?.addObserver { event in
                if case let .visibilityChanged(isVisible) = event {
                    isChatSectionVisible = isVisible
                }
            }
        }
        .onDisappear {
            chatObserverHandle?.cancel()
            chatObserverHandle = nil
        }
        .onChange(of: contextRevision) { _, _ in
            Task { await refreshConversationPresence() }
        }
        .onAppear {
            guard contextObserverHandle == nil else { return }
            contextObserverHandle = context.addObserver { event in
                if case .conversationsChanged = event {
                    contextRevision &+= 1
                }
            }
        }
        .onDisappear {
            contextObserverHandle?.cancel()
            contextObserverHandle = nil
        }
    }

    /// 查询全库顶层对话总数，据此决定按钮是否值得展示：
    /// 全库没有任何对话时隐藏该入口，避免一个只能弹出空列表的按钮。
    private func refreshConversationPresence() async {
        let count = await context.conversations.conversationCount(projectPath: nil)
        hasAnyConversations = count > 0
    }
}
