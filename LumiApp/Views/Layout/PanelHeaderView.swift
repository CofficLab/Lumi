import SwiftUI

/// 面板头部区域视图：渲染当前激活插件提供的 Header 视图列表
///
/// 参考 VSCode 的面板布局，Header 区域位于插件主内容上方，
/// 由插件通过 PanelHeaderProvider 注册，通常包含工具栏按钮或状态信息。
struct PanelHeaderView: View {
    let activeItemId: String
    let headerViews: [AnyView]

    var body: some View {
        ForEach(headerViews.indices, id: \.self) { index in
            headerViews[index]
                .id("header-\(activeItemId)-\(index)")
        }
    }
}
