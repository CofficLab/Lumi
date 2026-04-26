import SwiftUI

/// 编辑器面板视图：左侧文件树 + 中间编辑器
///
/// 使用 HSplitView 实现可拖拽的双栏布局，宽度比自动保存到 UserDefaults。
/// 左栏显示项目文件树，中栏显示代码编辑器。
/// 右侧聊天栏由 AgentChatPlugin 通过 addSidebarView() 提供。
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
        }
        .background(SplitViewAutosaveConfigurator(autosaveName: storageKey))
    }
}

#Preview {
    EditorPanelView()
        .inRootView()
        .frame(width: 1200, height: 600)
}
