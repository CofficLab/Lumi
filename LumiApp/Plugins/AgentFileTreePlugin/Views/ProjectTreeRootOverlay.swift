import MagicKit
import SwiftUI

/// 文件树插件的根层包裹：监听全局选中文件，切换到本插件的 Agent 侧边栏 Tab。
struct ProjectTreeRootOverlay<Content: View>: View {
    @EnvironmentObject private var projectVM: ProjectVM
    @EnvironmentObject private var layoutVM: LayoutVM

    let content: Content

    var body: some View {
        content
            .onChange(of: projectVM.selectedFileURL) {
                guard projectVM.selectedFileURL != nil else { return }
                layoutVM.selectAgentSidebarTab(ProjectTreePlugin.id, reason: "ProjectTreeRootOverlay.file selected")
            }
    }
}
