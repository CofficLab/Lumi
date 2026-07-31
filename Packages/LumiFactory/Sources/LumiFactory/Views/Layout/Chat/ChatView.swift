import LumiKernel
import LumiUI
import SwiftUI

/// Chat 总视图，作为 ChatHeader / ChatToolbar / ChatSectionContent / ChatActionBar 的组合入口
struct ChatView: View {
    let kernel: LumiKernel
    @State private var isVisible: Bool = true

    var body: some View {
        Group {
            if isVisible {
                VStack(spacing: 0) {
                    ChatHeaderView(kernel: kernel)
                    ChatToolbarView(kernel: kernel)
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
    }
}
