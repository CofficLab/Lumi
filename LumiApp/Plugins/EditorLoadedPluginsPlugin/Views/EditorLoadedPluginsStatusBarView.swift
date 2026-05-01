import MagicKit
import SwiftUI

/// 编辑器插件状态栏悬浮按钮视图
///
/// 点击后展示已加载编辑器插件的详情弹窗。
struct EditorLoadedPluginsStatusBarView: View {
    var body: some View {
        StatusBarHoverContainer(
            detailView: EditorLoadedPluginsDetailView(),
            popoverWidth: 460,
            id: "lumi-editor-loaded-plugins"
        ) {
            HStack(spacing: 4) {
                Image(systemName: "puzzlepiece.extension")
                    .font(.system(size: 11))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }
}
