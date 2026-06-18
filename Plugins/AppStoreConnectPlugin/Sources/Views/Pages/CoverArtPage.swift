import LumiUI
import SwiftUI

struct CoverArtPage: View {
    @ObservedObject var viewModel: ConnectViewModel

    var body: some View {
        AppEmptyState(
            icon: "photo.artframe",
            title: AppStoreConnectLocalization.string("Cover Art Maker"),
            description: AppStoreConnectLocalization.string(
                "Design App Store cover images for %@. This workspace is under construction.",
                viewModel.selectedApp?.name ?? ""
            )
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
