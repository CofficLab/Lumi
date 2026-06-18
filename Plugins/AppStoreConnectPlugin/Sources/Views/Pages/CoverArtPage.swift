import LumiUI
import SwiftUI

struct CoverArtPage: View {
    @ObservedObject var viewModel: VM

    var body: some View {
        Group {
            if viewModel.selectedApp == nil {
                AppEmptyState(
                    icon: "square.grid.2x2",
                    title: AppStoreConnectLocalization.string("No App Selected"),
                    description: AppStoreConnectLocalization.string("Select an app from the Apps page or toolbar picker.")
                )
            } else {
                AppEmptyState(
                    icon: "photo.artframe",
                    title: AppStoreConnectLocalization.string("Cover Art Maker"),
                    description: AppStoreConnectLocalization.string(
                        "Design App Store cover images for %@. This workspace is under construction.",
                        viewModel.selectedApp?.name ?? ""
                    )
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
