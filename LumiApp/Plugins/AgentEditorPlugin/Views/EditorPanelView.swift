import SwiftUI

/// 编辑器面板视图：文件树 + 编辑器
///
/// 使用 HSplitView 实现可拖拽的双栏布局，宽度比自动保存到 UserDefaults。
struct EditorPanelView: View {
    @EnvironmentObject private var themeManager: ThemeManager

    /// 插件专属的 storage key，用于持久化内部分割比例
    private let storageKey = "Split.Panel.LumiEditor"

    var body: some View {
        HSplitView {
            // 文件树
            EditorFileTreeView()
                .frame(minWidth: 180, idealWidth: 260)
                .background(themeManager.activeAppTheme.sidebarBackgroundColor())
                .background(SplitViewWidthPersistence(storageKey: storageKey))

            // 代码编辑器
            EditorRootView()
        }
        .background(themeManager.activeAppTheme.workspaceBackgroundColor())
        .background(SplitViewAutosaveConfigurator(autosaveName: storageKey))
    }
}

#Preview {
    EditorPanelView()
        .inRootView()
        .frame(width: 1200, height: 600)
}
