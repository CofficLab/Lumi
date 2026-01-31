import SwiftUI

/// View扩展，提供便捷的根视图包装方法（主要用于Preview）
extension View {
    /// 将视图包装在根视图中，注入所有必要的环境对象
    /// 主要用于SwiftUI Preview，在预览时自动注入环境对象
    /// - Returns: 包装后的视图，包含所有环境对象
    func inRootView() -> some View {
        self
            .environmentObject(AppProvider())
            .environmentObject(PluginProvider())
    }
}

// MARK: - Preview

#Preview("App - Small Screen") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .inRootView()
        .frame(width: 800, height: 600)
}

#Preview("App - Big Screen") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .inRootView()
        .frame(width: 1200, height: 1200)
}
