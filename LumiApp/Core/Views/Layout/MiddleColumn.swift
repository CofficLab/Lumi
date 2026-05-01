import SwiftUI

/// 中间栏视图：不再有独立内容，布局由 LeftSidebar 统一驱动。
/// 保留为兼容占位，后续可移除。
struct MiddleColumn: View {
    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
