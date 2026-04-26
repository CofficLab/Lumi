import SwiftUI

/// 编辑器右侧聊天栏
///
/// 整合 Header（项目名、新建对话、语言、自动批准、工具、项目按钮）
/// + 消息列表 + 输入区，作为 EditorPlugin 面板视图的右侧部分。
struct ChatSidebarView: View {
    @EnvironmentObject var projectVM: ProjectVM
    @EnvironmentObject var pluginProvider: PluginVM

    var body: some View {
        VStack(spacing: 0) {
            chatHeader

            GlassDivider()

            ChatMessagesView()

            GlassDivider()

            InputView()
        }
        .frame(maxHeight: .infinity)
        .frame(minWidth: 320, idealWidth: 400)
    }

    // MARK: - Header

    private var chatHeader: some View {
        HStack(spacing: 0) {
            // 左侧：项目名
            ChatHeaderLeadingView()

            Spacer()

            // 右侧：功能按钮
            HStack(spacing: 12) {
                AutoApproveToggle()
                LanguageSelector()
                AvailableToolsButton()
                ProjectButton()
                NewChatButton()
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: AppConfig.headerHeight)
        .zIndex(100)
    }
}

// MARK: - Preview

#Preview("Chat Sidebar") {
    ChatSidebarView()
        .inRootView()
        .frame(width: 500, height: 700)
}
