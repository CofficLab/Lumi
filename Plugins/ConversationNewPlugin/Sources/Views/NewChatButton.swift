import KernelLumi
import LumiUI
import SwiftUI

/// 新会话按钮视图组件
public struct NewChatButton: View {
    let kernel: KernelLumi

    /// ChatSection 是否可见；不可见时整个按钮不渲染。
    @State private var isChatSectionVisible: Bool = true

    /// 当前是否有选中对话；未选中时不渲染（此时已处于"新建会话"状态）。
    @State private var hasSelectedConversation: Bool = false

    public init(kernel: KernelLumi) {
        self.kernel = kernel
    }

    public var body: some View {
        Group {
            if isChatSectionVisible && hasSelectedConversation {
                AppIconButton(
                    systemImage: "plus",
                ) {
                    kernel.conversations?.deselectConversation()
                }
            }
        }
        .onAppear {
            isChatSectionVisible = kernel.workspace?.isChatVisible ?? true
            hasSelectedConversation = kernel.conversations?.selectedConversationID != nil
        }
        .onChatSectionVisibleDidChange { visible in
            isChatSectionVisible = visible
        }
        .onLumiSelectedConversationDidChange { conversationID in
            hasSelectedConversation = conversationID != nil
        }
    }
}
