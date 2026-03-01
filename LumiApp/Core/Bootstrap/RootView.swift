import SwiftUI

/// View扩展，提供便捷的根视图包装方法（主要用于Preview）
extension View {
    /// 将视图包装在根视图中，注入所有必要的环境对象
    /// 主要用于SwiftUI Preview，在预览时自动注入环境对象
    /// - Returns: 包装后的视图，包含所有环境对象
    func inRootView() -> some View {
        self
            .environmentObject(AppProvider.shared)
            .environmentObject(PluginProvider.shared)
            .environmentObject(AgentProvider.shared)
            .environmentObject(MystiqueThemeManager()) // 注册主题管理器
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
