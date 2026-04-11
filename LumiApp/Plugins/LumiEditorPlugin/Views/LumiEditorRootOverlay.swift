import MagicKit
import SwiftUI

/// LumiEditor 根视图覆盖层
///
/// 始终存在于视图树中（通过 addRootView 包裹），监听 ProjectVM 中
/// selectedFileURL 的变化，当有新文件被选中时自动操作 LayoutVM
/// 将 LumiEditor 插件切换为当前活跃的 Detail 视图。
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
            layoutVM.selectAgentDetail(LumiEditorPlugin.id)
        }
    }
}
