import LumiUI
import SwiftUI

/// 工具栏上的会话列表入口按钮
///
/// 在窗口工具栏右上角显示一个聊天气泡图标，点击后弹出 Popover
/// 展示完整的会话列表，支持选择、删除、分页加载等操作。
public struct ConversationListPopoverButton: View {
    @EnvironmentObject private var projectVM: WindowProjectVM
    @State private var isPresented = false

    public var body: some View {
        if !projectVM.isProjectSelected {
            EmptyView()
        } else {
            conversationListButton
        }
    }

    private var conversationListButton: some View {
        AppIconButton(
            systemImage: "message.fill",
            label: String(localized: "会话列表", table: "ConversationList")
        ) {
            isPresented.toggle()
        }
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            ConversationListView()
                .frame(width: 300, height: 480)
        }
    }
}

// MARK: - Preview

#Preview("Conversation List Popover Button") {
    ConversationListPopoverButton()
        .padding()
        .inRootView()
}
