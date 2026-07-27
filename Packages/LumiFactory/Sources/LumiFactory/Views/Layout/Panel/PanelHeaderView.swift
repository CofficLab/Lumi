import LumiKernel
import LumiUI
import SwiftUI

/// 面板顶部内容视图
///
/// 只接收 kernel，所需数据（顶部条目）由视图自身从内核读取。
struct PanelHeaderView: View {
    @ObservedObject var kernel: LumiKernel

    @LumiTheme private var theme

    private var items: [PanelHeaderItem] {
        kernel.uiManager?.allPanelHeaderItems ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(items) { item in
                item.makeView()
                    .id(item.id)
            }
        }
    }
}
