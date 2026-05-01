import SwiftUI

/// 应用程序的主视图组件
/// 提供便捷的初始化方法和修饰符来配置 ContentView 的行为
///
/// 支持多窗口模式，每个窗口有独立的 WindowState
struct ContentLayout: View {
    /// 应用状态提供者环境对象
    @EnvironmentObject var app: GlobalVM

    /// 插件 VM 环境对象
    @EnvironmentObject var pluginProvider: PluginVM

    /// 初始侧边栏可见性
    private(set) var initialSidebarVisibility: Bool?

    /// 初始选中的会话 ID
    private(set) var initialConversationId: UUID?

    /// 初始项目路径
    private(set) var initialProjectPath: String?

    /// 初始化内容布局
    /// - Parameters:
    ///   - initialSidebarVisibility: 初始侧边栏可见性
    ///   - conversationId: 初始选中的会话 ID
    ///   - projectPath: 初始项目路径
    init(
        initialSidebarVisibility: Bool? = nil,
        conversationId: UUID? = nil,
        projectPath: String? = nil
    ) {
        self.initialSidebarVisibility = initialSidebarVisibility
        self.initialConversationId = conversationId
        self.initialProjectPath = projectPath
    }

    /// 视图主体
    var body: some View {
        ContentView(
            defaultSidebarVisibility: initialSidebarVisibility,
            initialConversationId: initialConversationId,
            initialProjectPath: initialProjectPath
        )
    }
}

// MARK: - Modifier

extension ContentLayout {
    /// 隐藏侧边栏
    func hideSidebar() -> ContentLayout {
        return ContentLayout(
            initialSidebarVisibility: false,
            conversationId: self.initialConversationId,
            projectPath: self.initialProjectPath
        )
    }

    /// 显示侧边栏
    func showSidebar() -> ContentLayout {
        return ContentLayout(
            initialSidebarVisibility: true,
            conversationId: self.initialConversationId,
            projectPath: self.initialProjectPath
        )
    }

    /// 设置初始会话
    func withConversation(_ conversationId: UUID?) -> ContentLayout {
        return ContentLayout(
            initialSidebarVisibility: self.initialSidebarVisibility,
            conversationId: conversationId,
            projectPath: self.initialProjectPath
        )
    }

    /// 设置初始项目
    func withProject(_ projectPath: String?) -> ContentLayout {
        return ContentLayout(
            initialSidebarVisibility: self.initialSidebarVisibility,
            conversationId: self.initialConversationId,
            projectPath: projectPath
        )
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
