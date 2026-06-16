import LumiUI
import SwiftUI

struct AppChrome: View {
    @ObservedObject var viewModel: AppStoreConnectViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                if let app = viewModel.selectedApp {
                    IconView(url: app.iconURL, size: 28)
                    Text(app.name)
                        .font(.headline)
                        .lineLimit(1)
                } else {
                    Text(AppStoreConnectLocalization.string("App Store"))
                        .font(.headline)
                }

                if viewModel.selectedApp != nil {
                    Picker("", selection: Binding(
                        get: { viewModel.page == .xcodeCloud ? AppStoreConnectViewModel.Page.xcodeCloud : .distribution },
                        set: { viewModel.navigate(to: $0) }
                    )) {
                        Text(AppStoreConnectLocalization.string("Distribution")).tag(AppStoreConnectViewModel.Page.distribution)
                        Text(AppStoreConnectLocalization.string("Xcode Cloud")).tag(AppStoreConnectViewModel.Page.xcodeCloud)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 320)
                }

                Spacer()

                Text(viewModel.connectionStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if viewModel.page == .distribution, viewModel.metadataIsDirty {
                    Text(AppStoreConnectLocalization.string("Unsaved changes"))
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                AppButton(AppStoreConnectLocalization.string("Refresh"), systemImage: "arrow.clockwise", size: .small) {
                    Task { await viewModel.refreshCurrentPage() }
                }
                .disabled(!viewModel.credentials.isComplete || viewModel.isBusy)

                if viewModel.page == .distribution {
                    AppButton(AppStoreConnectLocalization.string("Save Metadata"), systemImage: "square.and.arrow.down", style: .primary, size: .small) {
                        Task { await viewModel.saveMetadata() }
                    }
                    .disabled(!viewModel.metadataIsDirty || viewModel.isBusy)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .background(.bar)
    }
}
