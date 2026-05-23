import LumiUI
import SwiftUI

/// 工具栏上的会话列表入口按钮
///
/// 在窗口工具栏右上角显示一个聊天气泡图标，点击后弹出 Popover
/// 展示完整的会话列表，支持选择、删除、分页加载等操作。
///
/// 使用原生 Button 而非自定义 AppIconButton。
/// 系统工具栏会自动控制按钮的样式和尺寸，原生 Button 可以更好地
/// 适配工具栏的外观变化，保持与系统风格一致。
struct ConversationListPopoverButton: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @EnvironmentObject private var projectVM: WindowProjectVM
    @State private var isPresented = false

    private let iconButtonSize: CGFloat = 28

    var body: some View {
        if !projectVM.isProjectSelected {
            EmptyView()
        } else {
            conversationListButton
        }
    }

    private var conversationListButton: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "message.fill")
                .font(.appCallout)
                .foregroundColor(theme.textSecondary)
                .frame(width: iconButtonSize, height: iconButtonSize)
                .clipShape(Circle())
        }
        .help(String(localized: "会话列表", table: "ConversationList"))
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
