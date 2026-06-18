import LumiUI
import SwiftUI

struct DistributionPage: View {
    @ObservedObject var viewModel: VM
    @Binding var importingScreenshots: Bool

    var body: some View {
        Group {
            if viewModel.selectedApp == nil {
                AppEmptyState(
                    icon: "square.grid.2x2",
                    title: AppStoreConnectLocalization.string("No App Selected"),
                    description: AppStoreConnectLocalization.string("Select an app from the Apps page or toolbar picker.")
                )
            } else if viewModel.selectedVersion == nil {
                AppEmptyState(
                    icon: "number",
                    title: AppStoreConnectLocalization.string("No Version Selected"),
                    description: AppStoreConnectLocalization.string("Choose a version from the sidebar to manage distribution.")
                )
            } else if let version = viewModel.selectedVersion, viewModel.isReadOnlyVersion {
                ReadOnlyPage(viewModel: viewModel, version: version)
            } else if let version = viewModel.selectedVersion {
                EditablePage(
                    viewModel: viewModel,
                    version: version,
                    importingScreenshots: $importingScreenshots
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: viewModel.selectedScreenshotDisplayType) { _, _ in
            Task { await viewModel.reloadScreenshotsForSelectedDisplayType() }
        }
    }
}
