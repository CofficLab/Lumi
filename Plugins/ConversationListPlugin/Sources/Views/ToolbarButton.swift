import LumiKernel
import LumiUI
import SwiftUI

/// 工具栏会话列表按钮
struct ToolbarButton: View {
    let kernel: LumiKernel
    @State private var isPresented = false

    var body: some View {
        AppIconButton(
            systemImage: "message.fill",
        ) {
            isPresented.toggle()
        }
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            ListView(kernel: kernel)
                .frame(width: 300, height: 480)
        }
    }
}