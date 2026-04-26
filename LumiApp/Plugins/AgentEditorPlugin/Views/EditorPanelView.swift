import SwiftUI

/// 编辑器面板视图：左侧文件树 + 中间编辑器 + 右侧聊天栏
///
/// 使用 HSplitView 实现可拖拽的三栏布局，宽度比自动保存到 UserDefaults。
/// 左栏显示项目文件树，中栏显示代码编辑器，右栏显示聊天界面。
struct EditorPanelView: View {
    /// 插件专属的 storage key，用于持久化内部分割比例
    private let storageKey = "Split.Panel.LumiEditor"

    var body: some View {
        HSplitView {
            // 左栏：文件树
            ProjectTreeView()
                .frame(minWidth: 180, idealWidth: 260)
                .background(SplitViewWidthPersistence(storageKey: storageKey))

            // 中栏：代码编辑器
            EditorRootView()

            // 右栏：聊天栏
            ChatSidebarView()
                .frame(minWidth: 320, idealWidth: 400)
        }
        .background(SplitViewAutosaveConfigurator(autosaveName: storageKey))
    }
}

#Preview {
    EditorPanelView()
        .inRootView()
        .frame(width: 1200, height: 600)
}
