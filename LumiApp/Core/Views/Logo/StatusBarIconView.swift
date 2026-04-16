import SwiftUI

/// 状态栏图标视图
/// 显示 Logo 图标和插件提供的内容视图
struct StatusBarIconView: View {
    @ObservedObject var viewModel: StatusBarIconVM

    var body: some View {
        HStack(spacing: 4) {
            // Logo 图标
            LogoView(scene: viewModel.isActive ? .statusBarActive : .statusBarInactive)
                .frame(width: 22, height: 22)

            // 插件提供的内容视图
            ForEach(viewModel.contentViews.indices, id: \.self) { index in
                viewModel.contentViews[index]
            }
        }
        .frame(height: 20)
    }
}
