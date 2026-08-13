import KernelLumi
import SwiftUI

/// 状态栏中渲染所有 `LumiMenuBarContentItem` 的水平排布视图。
struct MenuBarIconView: View {
    let contentItems: [LumiMenuBarContentItem]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(contentItems) { item in
                item.makeView()
                    .fixedSize()
            }
        }
        .padding(.horizontal, 4)
        .frame(height: 22)
    }
}
