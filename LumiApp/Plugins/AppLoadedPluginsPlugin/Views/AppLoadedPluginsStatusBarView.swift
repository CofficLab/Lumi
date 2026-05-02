import MagicKit
import SwiftUI

/// App 插件状态栏悬浮按钮视图
///
/// 点击后展示已加载 App 插件的详情弹窗。
struct AppLoadedPluginsStatusBarView: View {
    var body: some View {
        StatusBarHoverContainer(
            detailView: AppLoadedPluginsDetailView(),
            popoverWidth: 460,
            id: "lumi-app-loaded-plugins"
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
