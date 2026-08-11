import LumiUI
import SwiftUI

/// AppStoreConnect 侧边栏 Rail 视图。
///
/// 由 `AppStoreConnectPlugin` 注册为 `PanelRailTabItem`，
/// 仅在 app-store-connect ViewContainer 中可见。
/// 与主内容 `MainView` 共享同一个 `VM.shared`，选中状态自动同步。
struct AppStoreConnectRailView: View {
    @ObservedObject var viewModel: VM

    init(viewModel: VM = .shared) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if viewModel.selectedApp != nil {
                VersionsSection(viewModel: viewModel)
                    .padding(.top, 6)
            }

            Spacer(minLength: 0)

            AppSettingsDivider()
            sidebarSection(AppStoreConnectLocalization.string("General")) {
                sidebarButton(.account)
                sidebarButton(.apps)
            }
            .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func sidebarSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            AppSectionLabel(title)
                .padding(.horizontal, 12)
                .padding(.top, 10)

            content()
        }
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
