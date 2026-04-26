import SwiftUI

/// 应用顶部工具栏视图
///
/// 将原聊天栏头部的小功能项注入到 macOS 原生工具栏中。
/// 包含：项目名选择器、自动批准开关、语言选择器、工具按钮、项目管理、新建对话。
struct AppToolbarLeading: ToolbarContent {
    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            // 项目名选择器
            ChatHeaderLeadingView()
                .help("选择项目")
        }
    }
}

struct AppToolbarTrailing: ToolbarContent {
    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
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
        }
    }
}

// MARK: - View Toolbar Modifier

/// 为视图添加应用工具栏的便捷修饰符
struct AppToolbarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbar {
                AppToolbarLeading()
                AppToolbarTrailing()
            }
    }
}

extension View {
    /// 添加应用级别的工具栏（项目选择器、自动批准、语言、工具、新建对话等）
    func withAppToolbar() -> some View {
        modifier(AppToolbarModifier())
    }
}
