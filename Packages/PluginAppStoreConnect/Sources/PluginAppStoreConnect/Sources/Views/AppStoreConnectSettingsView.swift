import LumiUI
import ProviderSettingView
import SwiftUI

/// App Store Connect 的设置入口：集中配置 API 凭据，并显示当前连接状态。
struct AppStoreConnectSettingsView: View {
    @ObservedObject private var viewModel: VM
    @State private var showingAccountGuide = false

    init(viewModel: VM) {
        self.viewModel = viewModel
    }

    var body: some View {
        PluginSettingsScaffold(
            title: AppStoreConnectLocalization.string("AppStoreConnect"),
            subtitle: AppStoreConnectLocalization.string("Configure App Store Connect API credentials and connection status."),
            showHeader: true,
            scrollsContent: false
        ) {
            AccountPage(
                viewModel: viewModel,
                showingAccountGuide: $showingAccountGuide
            )
        }
        .sheet(isPresented: $showingAccountGuide) {
            AccountGuideView()
        }
    }
}
