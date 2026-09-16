import LumiUI
import SwiftUI

/// App Store Connect 工作区的全局工具栏刷新按钮。
@MainActor
struct AppStoreConnectRefreshToolbarButton: View {
    @ObservedObject var viewModel: VM

    var body: some View {
        AppIconButton(systemImage: "arrow.clockwise") {
            Task { await viewModel.refreshWorkspace() }
        }
        .disabled(!viewModel.credentials.isComplete || viewModel.isBusy)
        .help(AppStoreConnectLocalization.string("Refresh"))
    }
}
