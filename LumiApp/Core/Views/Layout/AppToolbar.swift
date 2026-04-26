import SwiftUI

/// 应用顶部工具栏
///
/// 动态收集所有插件通过 `addToolBarLeadingView()` 和
/// `addToolBarTrailingView()` 注册的工具栏组件。
/// 插件按 `order` 排序，确保工具栏项的显示顺序稳定。
struct AppToolbar: ToolbarContent {
    @EnvironmentObject var pluginProvider: PluginVM

    var body: some ToolbarContent {
        let leadingViews = pluginProvider.getToolbarLeadingViews()
        let trailingViews = pluginProvider.getToolbarTrailingViews()

        ToolbarItemGroup(placement: .status) {
            // 左侧视图（按插件 order 排列）
            ForEach(leadingViews.indices, id: \.self) { index in
                leadingViews[index]
                    .id("toolbar_leading_\(index)")
            }

            Spacer()

            // 右侧视图（按插件 order 排列）
            ForEach(trailingViews.indices, id: \.self) { index in
                trailingViews[index]
                    .id("toolbar_trailing_\(index)")
            }
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
