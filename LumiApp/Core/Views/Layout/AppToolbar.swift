import SwiftUI

/// 应用顶部工具栏
///
/// 所有按钮统一放在工具栏最右侧。
/// 包含：项目名选择器、自动批准开关、语言选择器、工具按钮、项目管理、新建对话、会话列表。
struct AppToolbar: ToolbarContent {
    var body: some ToolbarContent {
        // 占位：让 primaryAction 区域被推到最右
        ToolbarItemGroup(placement: .primaryAction) {
            Spacer()

            // 项目名选择器
            ChatHeaderLeadingView()

            // 自动批准开关
            AutoApproveToggle()

            // 语言选择器
            LanguageSelector()

            // 可用工具
            AvailableToolsButton()

            // 项目管理
            ProjectButton()

            // 新建对话
            NewChatButton()

            // 会话列表
            ConversationListPopoverButton()
        }
    }
}

// MARK: - View Toolbar Modifier

/// 为视图添加应用工具栏的便捷修饰符
struct AppToolbarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbar {
                AppToolbar()
            }
    }
}

extension View {
    /// 添加应用级别的工具栏
    func withAppToolbar() -> some View {
        modifier(AppToolbarModifier())
    }
}
