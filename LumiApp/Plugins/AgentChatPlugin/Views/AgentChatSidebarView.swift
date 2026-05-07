import SwiftUI

/// Agent 聊天右侧栏视图
///
/// 整合消息列表和输入区域，作为插件提供的右侧栏。
/// 通过 AgentChatPlugin 的 `addSidebarView()` 注册。
struct AgentChatSidebarView: View {
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
    AgentChatSidebarView()
        .inRootView()
        .frame(width: 500, height: 700)
}
