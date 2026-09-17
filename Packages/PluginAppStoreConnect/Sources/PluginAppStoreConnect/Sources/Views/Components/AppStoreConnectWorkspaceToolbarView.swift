import LumiUI
import SwiftUI

/// App Store Connect 工作区切换控件，显示在 App 的全局工具栏中间。
struct AppStoreConnectWorkspaceToolbarView: View {
    @ObservedObject var viewModel: VM

    var body: some View {
        if viewModel.selectedApp != nil {
            AppSegmentedControl(
                [
                    AppStoreConnectLocalization.string("Distribution"),
                    AppStoreConnectLocalization.string("Xcode Cloud")
                ],
                selection: Binding(
                    get: { viewModel.page == .xcodeCloud ? 1 : 0 },
                    set: { index in
                        viewModel.navigate(to: index == 1 ? .xcodeCloud : .distribution)
                    }
                ),
                maxWidth: 320
            )
        }
    }
}
