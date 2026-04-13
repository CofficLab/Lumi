import MagicKit
import SwiftUI

/// LumiEditor 根视图覆盖层
struct LumiEditorRootOverlay<Content: View>: View {
    @EnvironmentObject private var projectVM: ProjectVM
    @EnvironmentObject private var layoutVM: LayoutVM

    let content: Content

    var body: some View {
        ZStack {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: projectVM.selectedFileURL) { _, newURL in
            guard newURL != nil else { return }
            // 有文件被选中时，激活代码编辑器 Detail 和文件树 Sidebar
            layoutVM.selectAgentDetail(LumiEditorPlugin.id)
            layoutVM.selectAgentSidebarTab(ProjectTreePlugin.id, reason: "LumiEditorRootOverlay.file selected")
        }
    }
}
