import LumiUI
import SwiftUI

/// AppStoreConnect 侧边栏 Rail 视图。
///
/// 由 `AppStoreConnectPlugin` 注册为 `PanelRailTabItem`，
/// 仅在 app-store-connect ViewContainer 中可见。
/// 从上到下显示：账户、APP列表。
/// 与主内容 `MainView` 共享同一个 `VM.shared`，选中状态自动同步。
struct AppStoreConnectRailView: View {
    @ObservedObject var viewModel: VM

    init(viewModel: VM = .shared) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 账户按钮
            sidebarButton(.account)
            
            Divider()
                .padding(.vertical, 6)
            
            // APP 列表（占满剩余空间）
            AppListSection(viewModel: viewModel)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func sidebarButton(_ page: VM.Page) -> some View {
        AppSidebarRow(
            title: page.title,
            systemImage: page.systemImage,
            isSelected: viewModel.page == page,
            action: { viewModel.navigate(to: page) }
        )
    }
}
