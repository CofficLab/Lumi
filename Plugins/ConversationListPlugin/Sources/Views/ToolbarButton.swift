import LumiKernel
import LumiUI
import SwiftUI

/// 工具栏会话列表按钮
///
/// 仅在 Chat 区块可见时渲染。不可见时整个按钮消失，键盘/工具栏
/// 流程自然略过它（参考 `ConversationNewPlugin.NewChatButton` 的模式）。
struct ToolbarButton: View {
    let kernel: LumiKernel
    let attentionStore: ConversationAttentionStore
    @State private var isPresented = false

    /// ChatSection 是否可见；不可见时整个按钮不渲染。
    @State private var isChatSectionVisible: Bool = true

    var body: some View {
        Group {
            if isChatSectionVisible {
                AppIconButton(
                    systemImage: "message.fill",
                ) {
                    isPresented.toggle()
                }
                .popover(isPresented: $isPresented, arrowEdge: .bottom) {
                    ToolbarPopoverContent(kernel: kernel, attentionStore: attentionStore)
                }
            }
        }
        .onAppear {
            isChatSectionVisible = kernel.workspace?.isChatVisible ?? true
        }
        .onChatSectionVisibleDidChange { visible in
            isChatSectionVisible = visible
        }
    }
}
