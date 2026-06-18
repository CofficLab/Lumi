import LumiUI
import SwiftUI

private let appStoreToolbarPadding = EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)

struct TopBar: View {
    @ObservedObject var viewModel: ConnectViewModel

    var body: some View {
        AppToolbarContainer(padding: appStoreToolbarPadding) {
            HStack(spacing: 16) {
                if viewModel.selectedApp != nil {
                    Picker("", selection: Binding(
                        get: { viewModel.page == .xcodeCloud ? ConnectViewModel.Page.xcodeCloud : .distribution },
                        set: { viewModel.navigate(to: $0) }
                    )) {
                        Text(AppStoreConnectLocalization.string("Distribution")).tag(ConnectViewModel.Page.distribution)
                        Text(AppStoreConnectLocalization.string("Xcode Cloud")).tag(ConnectViewModel.Page.xcodeCloud)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 320)
                }

                Spacer()

                if viewModel.page == .distribution, viewModel.metadataIsDirty {
                    Text(AppStoreConnectLocalization.string("Unsaved changes"))
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                AppButton(AppStoreConnectLocalization.string("Refresh"), systemImage: "arrow.clockwise", size: .small) {
                    Task { await viewModel.refreshCurrentPage() }
                }
                .disabled(!viewModel.credentials.isComplete || viewModel.isBusy)

                if viewModel.page == .distribution, !viewModel.isReadOnlyVersion {
                    AppButton(AppStoreConnectLocalization.string("Save Metadata"), systemImage: "square.and.arrow.down", style: .primary, size: .small) {
                        Task { await viewModel.saveMetadata() }
                    }
                    .disabled(!viewModel.metadataIsDirty || viewModel.isBusy)
                    .appStoreConnectAddToChatMenu(
                        entityType: "uiActionButton",
                        entityID: "distribution.saveMetadata",
                        title: "Save Metadata",
                        sourceView: "AppChrome",
                        fields: [
                            "actionID": "saveMetadata",
                            "disabled": (!viewModel.metadataIsDirty || viewModel.isBusy) ? "true" : "false",
                            "isBusy": viewModel.isBusy ? "true" : "false",
                            "metadataIsDirty": viewModel.metadataIsDirty ? "true" : "false"
                        ]
                    )
                }
            }
        }
    }
}
