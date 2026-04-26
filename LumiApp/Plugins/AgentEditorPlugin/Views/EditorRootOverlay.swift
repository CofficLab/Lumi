import MagicKit
import SwiftUI

/// Editor 根视图覆盖层
///
/// 包裹 RootView，确保文件选择监听始终生效。
/// 文件选中时自动激活 EditorPlugin 的面板视图。
struct EditorRootOverlay<Content: View>: View {
    @EnvironmentObject private var projectVM: ProjectVM
    @EnvironmentObject private var layoutVM: LayoutVM

    let content: Content

    var body: some View {
        ZStack {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: projectVM.selectedFileURL) {
            guard projectVM.selectedFileURL != nil else { return }

            if EditorPlugin.verbose {
                EditorPlugin.logger.info("File selected, activating EditorPlugin panel")
            }

            // 有文件被选中时，激活编辑器面板
            if layoutVM.selectedAgentSidebarTabId != EditorPlugin.id {
                layoutVM.selectAgentSidebarTab(EditorPlugin.id, reason: "EditorRootOverlay: file selected")
            }
        }
    }
}
