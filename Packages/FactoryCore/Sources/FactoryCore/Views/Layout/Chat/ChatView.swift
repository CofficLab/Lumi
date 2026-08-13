import KernelLumi
import LumiUI
import SwiftUI

/// Chat 总视图，作为 ChatHeader / ChatToolbar / ChatSectionContent / ChatActionBar 的组合入口
struct ChatView: View {
    let kernel: KernelLumi
    @State private var isVisible: Bool = true

    /// 快照 + 事件刷新(同 ChatHeaderView / ListView 模式):不订阅 kernel 的 objectWillChange。
    /// init 同步读初值,避免首次渲染错位;之后由 `.onLumiSelectedConversationDidChange` 驱动更新。
    /// 未选择会话时隐藏 ChatHeader / ChatToolbar,仅保留正文与输入区。
    @State private var selectedConversationID: UUID?

    init(kernel: KernelLumi) {
        self.kernel = kernel
        _selectedConversationID = State(initialValue: kernel.conversations?.selectedConversationID)
    }

    var body: some View {
        Group {
            if isVisible {
                VStack(spacing: 0) {
                    if selectedConversationID != nil {
                        ChatHeaderView(kernel: kernel)
                        ChatToolbarView(kernel: kernel)
                    }
                    ChatSectionContentView(kernel: kernel)
                        .frame(maxHeight: .infinity)
                    ChatActionBar(kernel: kernel)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .onAppear {
            isVisible = kernel.workspace?.isChatVisible ?? true
        }
        .onChatSectionVisibleDidChange { visible in
            isVisible = visible
        }
        .onLumiSelectedConversationDidChange { newID in
            selectedConversationID = newID
        }
    }
}
