import LumiUI
import SwiftUI

/// AppStoreConnect 侧边栏 Rail 视图。
///
/// 由 `AppStoreConnectPlugin` 注册为当前 Rail provider 的 `RailTabItem`，
/// 仅在 App Store Connect 工作区入口激活时可见。
/// 直接显示应用列表与版本列表；凭据配置位于系统设置中的插件入口。
/// 与主内容 `MainView` 共享同一个 `VM.shared`，选中状态自动同步。
struct AppStoreConnectRailView: View {
    @ObservedObject var viewModel: VM

    init(viewModel: VM = .shared) {
        self.viewModel = viewModel
    }

    var body: some View {
        AppListSection(viewModel: viewModel)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
