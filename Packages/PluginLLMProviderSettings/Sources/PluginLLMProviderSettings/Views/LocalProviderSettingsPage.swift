import SwiftUI

/// 本地供应商设置页面。
///
/// View 只依赖 `ProviderSettingsPageViewModel`，不直接持有 manager / Store / downloader。
@MainActor
public struct LocalProviderSettingsPage: View {
    @ObservedObject private var viewModel: ProviderSettingsPageViewModel

    init(viewModel: ProviderSettingsPageViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ProviderSettingsPageContent(viewModel: viewModel)
    }
}
