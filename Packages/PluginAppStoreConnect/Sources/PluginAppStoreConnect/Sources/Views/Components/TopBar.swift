import LumiUI
import SwiftUI

let appStoreToolbarPadding = EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)

struct TopBar: View {
    @ObservedObject var viewModel: VM

    var body: some View {
        AppToolbarContainer(padding: appStoreToolbarPadding) {
            HStack(spacing: 16) {
                Spacer()

                if viewModel.page == .distribution, viewModel.metadataIsDirty {
                    Text(AppStoreConnectLocalization.string("Unsaved changes"))
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if viewModel.page == .distribution,
                   viewModel.selectedVersion != nil,
                   !viewModel.isReadOnlyVersion {
                    AppButton(AppStoreConnectLocalization.string("Save Metadata"), systemImage: "square.and.arrow.down", style: .primary, size: .small) {
                        Task { await viewModel.saveMetadata() }
                    }
                    .disabled(!viewModel.metadataIsDirty || viewModel.isBusy)
                    .appStoreConnectAddToChatMenu(
                        entityType: "uiActionButton",
                        entityID: "distribution.saveMetadata",
                        title: AppStoreConnectLocalization.string("Save Metadata"),
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
