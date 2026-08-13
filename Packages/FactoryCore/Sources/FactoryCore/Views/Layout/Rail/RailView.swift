import KernelLumi
import LumiUI
import SwiftUI

/// Rail 视图，显示侧边栏 tab bar 和内容
///
/// 自己从 kernel 获取 tabs 和状态，AppLayoutView 不需要了解其内部细节。
struct RailView: View {
    @ObservedObject var kernel: KernelLumi

    @LumiTheme private var theme

    private static let minWidth: CGFloat = 200

    var body: some View {
        VStack(spacing: 0) {
            RailTabBarView(kernel: kernel)

            RailContentView(kernel: kernel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: Self.minWidth, maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.surface)
    }
}
