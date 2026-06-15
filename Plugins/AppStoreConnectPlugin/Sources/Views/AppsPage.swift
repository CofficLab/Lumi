import LumiUI
import SwiftUI

struct AppsPage: View {
    @ObservedObject var viewModel: AppStoreConnectViewModel

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(
                title: AppStoreConnectLocalization.string("Apps"),
                subtitle: AppStoreConnectLocalization.string("Browse and select an App Store Connect app")
            )

            HStack {
                AppSearchBar(text: $viewModel.searchText, placeholder: LocalizedStringKey(AppStoreConnectLocalization.string("Search by name, bundle ID, or SKU")))
                    .frame(maxWidth: 420)

                AppButton(AppStoreConnectLocalization.string("Load Apps"), systemImage: "square.and.arrow.down", size: .small) {
                    Task { await viewModel.loadApps() }
                }
                .disabled(!viewModel.credentials.isComplete)

                Spacer()
            }
            .padding()

            if viewModel.filteredApps.isEmpty {
                AppEmptyState(
                    icon: "square.grid.2x2",
                    title: AppStoreConnectLocalization.string("No Apps"),
                    description: viewModel.credentials.isComplete
                        ? AppStoreConnectLocalization.string("Load apps from App Store Connect or adjust your search.")
                        : AppStoreConnectLocalization.string("Configure API credentials on the Account page first.")
                )
            } else {
                List(selection: Binding(
                    get: { viewModel.selectedApp?.id },
                    set: { id in
                        if let id, let app = viewModel.apps.first(where: { $0.id == id }) {
                            viewModel.selectApp(app, openDistribution: true)
                        }
                    }
                )) {
                    ForEach(viewModel.filteredApps) { app in
                        AppRow(app: app)
                            .tag(app.id)
                    }
                }
                .listStyle(.inset)
            }
        }
    }
}
