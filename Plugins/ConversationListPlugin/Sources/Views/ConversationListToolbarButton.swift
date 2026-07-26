import Foundation
import LumiKernel
import LumiUI
import SwiftUI

/// 工具栏会话列表按钮
struct ConversationListToolbarButton: View {
    let kernel: LumiKernel
    @State private var isPresented = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            AppIconButton(
                systemImage: "message.fill",
            ) {
                isPresented.toggle()
            }
            .popover(isPresented: $isPresented, arrowEdge: .bottom) {
                ConversationListPopoverContent(kernel: kernel)
                    .frame(width: 300, height: 480)
            }
        }
    }
}
