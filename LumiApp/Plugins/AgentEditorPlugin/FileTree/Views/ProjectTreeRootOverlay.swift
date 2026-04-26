import MagicKit
import SwiftUI

/// 文件树的根层包裹：监听全局选中文件，切换到编辑器面板。
struct ProjectTreeRootOverlay<Content: View>: View {
    @EnvironmentObject private var projectVM: ProjectVM
    @EnvironmentObject private var layoutVM: LayoutVM

    let content: Content

    var body: some View {
        content
            .onChange(of: projectVM.selectedFileURL) {
                guard projectVM.selectedFileURL != nil else { return }
                layoutVM.selectAgentSidebarTab(EditorPlugin.id, reason: "ProjectTreeRootOverlay.file selected")
            }
    }
}
