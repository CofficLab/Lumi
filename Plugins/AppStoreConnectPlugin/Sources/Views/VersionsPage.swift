import LumiUI
import SwiftUI

struct VersionsPage: View {
    @ObservedObject var viewModel: AppStoreConnectViewModel

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(
                title: AppStoreConnectLocalization.string("Versions"),
                subtitle: viewModel.selectedApp.map { AppStoreConnectLocalization.string("App Store versions for %@", $0.name) } ?? AppStoreConnectLocalization.string("Select an app first")
            )

            List(selection: Binding(
                get: { viewModel.selectedVersion?.id },
                set: { id in
                    if let id, let version = viewModel.versions.first(where: { $0.id == id }) {
                        viewModel.selectVersion(version)
                    }
                }
            )) {
                ForEach(viewModel.versions) { version in
                    VersionRow(version: version)
                        .tag(version.id)
                }
            }
            .listStyle(.inset)
        }
    }
}
