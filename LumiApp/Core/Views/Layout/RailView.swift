import SwiftUI

/// Rail 视图：位于活动栏与面板内容区之间的辅助栏
///
/// Rail 是一个窄型过渡栏，允许插件提供上下文相关的辅助视图，
/// 例如文件浏览器树、符号大纲、书签列表等。
///
/// ## 渲染规则
///
/// - **0 个插件提供**：不渲染，布局中不占空间
/// - **1 个插件提供**：正常渲染该插件的 Rail 视图
/// - **多个插件提供**：渲染 `RailConflictGuideView` 错误视图
struct RailView: View {
    @EnvironmentObject private var pluginProvider: PluginVM
    @EnvironmentObject private var themeManager: ThemeManager

    /// Rail 栏默认最小宽度
    static let minWidth: CGFloat = 200

    /// Rail 栏默认最大宽度
    static let maxWidth: CGFloat = 300

    var body: some View {
        let railItems = pluginProvider.getRailItems()

        Group {
            switch railItems.count {
            case 0:
                // 无插件提供 Rail，不渲染
                EmptyView()

            case 1:
                // 恰好一个插件，正常渲染
                railItems[0].view
                    .frame(minWidth: Self.minWidth, maxWidth: Self.maxWidth)

            default:
                // 多个插件冲突，显示错误视图
                RailConflictGuideView(
                    conflictingPluginIds: railItems.map(\.id)
                )
                .frame(minWidth: Self.minWidth, maxWidth: Self.maxWidth)
            }
        }
        .background(themeManager.activeAppTheme.sidebarBackgroundColor())
    }
}
