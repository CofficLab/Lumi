import LumiUI
import SwiftUI

/// 应用管理器操作栏容器
///
/// 固定高度 40px 的外部容器，统一包裹三块内容。
/// 作为侧边栏顶部、侧边栏底部、详情面板底部的通用容器。
struct ActionBar<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack {
            content()
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(Material.regularMaterial)
    }
}
