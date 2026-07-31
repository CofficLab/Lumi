import LumiKernel
import LumiUI
import SwiftUI

/// 新会话按钮视图组件
public struct NewChatButton: View {
    let kernel: LumiKernel

    /// ChatSection 是否可见；不可见时整个按钮不渲染。
    @State private var isChatSectionVisible: Bool = true

    public init(kernel: LumiKernel) {
        self.kernel = kernel
    }

    public var body: some View {
        Group {
            if isChatSectionVisible {
                AppIconButton(
                    systemImage: "plus",
                ) {
                    kernel.conversations?.deselectConversation()
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
