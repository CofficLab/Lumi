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

            Divider()
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
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 10)

            content()
        }
    }

    private func sidebarButton(_ page: VM.Page) -> some View {
        Button {
            viewModel.navigate(to: page)
        } label: {
            Label(page.title, systemImage: page.systemImage)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(viewModel.page == page ? Color.accentColor.opacity(0.16) : Color.clear)
    }
}
