import SwiftData
import SwiftUI

/// 根视图容器组件
/// 为应用提供统一的上下文环境，管理核心服务初始化和环境注入
struct RootView<Content>: View where Content: View {
    /// 视图内容
    var content: Content

    /// SwiftData 模型容器
    let modelContainer: ModelContainer

    init(@ViewBuilder content: () -> Content) {
        self.content = content()

        // 初始化 SwiftData 容器
        self.modelContainer = AppConfig.getContainer()

        // 初始化聊天历史服务
        ChatHistoryService.shared.initializeWithContainer(self.modelContainer, reason: "主窗口初始化")
    }

    var body: some View {
        content
            .environmentObject(AppProvider.shared)
            .environmentObject(PluginProvider.shared)
            .environmentObject(AgentProvider.shared)
            .environmentObject(ConversationViewModel.shared)
            .environmentObject(CommandSuggestionViewModel.shared)
            .environmentObject(MystiqueThemeManager())
            .modelContainer(modelContainer)
    }
}

extension View {
    /// 将视图包装在 RootView 中，注入所有必要的环境对象和模型容器
    /// - Parameter reason: 初始化原因（用于日志）
    /// - Returns: 包装在 RootView 中的视图
    func inRootView(_ reason: String) -> some View {
        AnyView(RootView(content: { self }, reason: reason))
    }
}

extension RootView {
    /// 初始化 RootView，支持传入初始化原因
    init(@ViewBuilder content: () -> Content, reason: String) {
        self.content = content()
        self.modelContainer = AppConfig.getContainer()
        ChatHistoryService.shared.initializeWithContainer(self.modelContainer, reason: reason)
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView("Preview")
        .withDebugBar()
}
