import SwiftUI

/// 编辑器右侧聊天栏
///
/// 纯粹的消息列表 + 输入区，不包含头部功能按钮。
/// 功能按钮（项目名、自动批准、语言、工具、新建对话等）已提升到窗口工具栏。
struct ChatSidebarView: View {
    var body: some View {
        VStack(spacing: 0) {
            ChatMessagesView()

            GlassDivider()

            InputView()
        }
        .frame(maxHeight: .infinity)
        .frame(minWidth: 320, idealWidth: 400)
    }
}

// MARK: - Preview

#Preview("Chat Sidebar") {
    ChatSidebarView()
        .inRootView()
        .frame(width: 500, height: 700)
}
